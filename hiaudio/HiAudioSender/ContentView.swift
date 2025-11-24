import SwiftUI
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @StateObject private var sender = BestSender()
    @State private var newIP = ""
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if sender.uiMode == .minimal {
                MinimalView(sender: sender, newIP: $newIP)
            } else if sender.uiMode == .unified {
                UnifiedDashboardView(sender: sender, newIP: $newIP)
            } else {
                VisualView(sender: sender, newIP: $newIP, selectedTab: $selectedTab)
            }
        }
        .preferredColorScheme(sender.colorScheme.colorScheme)
    }
}

// MARK: - Unified Dashboard (Dante-Style Control Station)
struct UnifiedDashboardView: View {
    @ObservedObject var sender: BestSender
    @Binding var newIP: String
    @State private var showingModeSelector = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Status Bar
            TopStatusBar(sender: sender)
            
            // Main Content Grid
            HStack(spacing: 0) {
                // Left Panel - Device Matrix
                VStack(spacing: 0) {
                    DeviceMatrixPanel(sender: sender, newIP: $newIP)
                }
                .frame(width: 400)
                .background(Color.black.opacity(0.3))
                
                // Center Panel - Meters & Visualization
                VStack(spacing: 0) {
                    MeterPanel(sender: sender)
                    Divider().background(Color.gray.opacity(0.3))
                    VisualizationPanel(sender: sender)
                }
                .frame(minWidth: 300)
                .background(Color.black.opacity(0.2))
                
                // Right Panel - Controls & Settings
                VStack(spacing: 0) {
                    ControlsPanel(sender: sender)
                }
                .frame(width: 300)
                .background(Color.black.opacity(0.3))
            }
            
            // Bottom Action Bar
            BottomActionBar(sender: sender, showingModeSelector: $showingModeSelector)
        }
        .frame(minWidth: 1000, minHeight: 700)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color(.darkGray).opacity(0.8)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .sheet(isPresented: $showingModeSelector) {
            ModeSelector(sender: sender)
        }
    }
}

// MARK: - Top Status Bar
struct TopStatusBar: View {
    @ObservedObject var sender: BestSender
    
    var body: some View {
        HStack(spacing: 30) {
            // App Identity
            HStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("HIAUDIO PRO")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("CONTROL STATION")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Critical Status Indicators
            HStack(spacing: 25) {
                StatusIndicator(
                    icon: sender.isStreaming ? "play.circle.fill" : "pause.circle.fill",
                    title: "POWER",
                    value: sender.isStreaming ? "LIVE" : "STANDBY",
                    color: sender.isStreaming ? .green : .gray,
                    isBlinking: sender.isStreaming
                )
                
                StatusIndicator(
                    icon: "speedometer",
                    title: "LATENCY",
                    value: "\(String(format: "%.1f", sender.averageLatency))ms",
                    color: latencyColor(sender.averageLatency),
                    isBlinking: false
                )
                
                StatusIndicator(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "NETWORK",
                    value: sender.networkHealth,
                    color: networkQualityColor(sender.networkHealth),
                    isBlinking: false
                )
                
                StatusIndicator(
                    icon: "dial.max",
                    title: "DEVICES",
                    value: "\(sender.discoveredDevices.filter { $0.isConnected }.count)/\(sender.discoveredDevices.count + sender.targetIPs.count)",
                    color: .cyan,
                    isBlinking: false
                )
            }
            
            Spacer()
            
            // Quick Actions
            HStack(spacing: 15) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        sender.colorScheme = sender.colorScheme == .dark ? .light : .dark
                    }
                }) {
                    Image(systemName: sender.colorScheme == .dark ? "sun.max" : "moon")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        sender.uiMode = .minimal
                    }
                }) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color.black.opacity(0.8))
        .border(Color.gray.opacity(0.3), width: 1)
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let isBlinking: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .scaleEffect(isBlinking ? 1.1 : 1.0)
                .animation(isBlinking ? .easeInOut(duration: 0.8).repeatForever() : .default, value: isBlinking)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
        }
    }
}

// MARK: - Device Matrix Panel
struct DeviceMatrixPanel: View {
    @ObservedObject var sender: BestSender
    @Binding var newIP: String
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Panel Header
            HStack {
                Image(systemName: "network")
                    .font(.system(size: 18))
                    .foregroundColor(.cyan)
                Text("DEVICE MATRIX")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                // Scanning indicator
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 14))
                    .foregroundColor(sender.isDiscovering ? .green : .gray)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(sender.isDiscovering ? 
                             .linear(duration: 2.0).repeatForever(autoreverses: false) : 
                             .default, value: rotationAngle)
                    .onAppear {
                        if sender.isDiscovering {
                            rotationAngle = 360
                        }
                    }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            
            // Device Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(sender.discoveredDevices.indices, id: \.self) { index in
                        DeviceMatrixCard(device: sender.discoveredDevices[index], sender: sender)
                    }
                    
                    ForEach(sender.targetIPs, id: \.self) { ip in
                        ManualDeviceCard(ip: ip, sender: sender)
                    }
                    
                    // Add Device Card
                    AddDeviceCard(newIP: $newIP, sender: sender)
                }
                .padding(15)
            }
        }
    }
}

// MARK: - Device Matrix Card
struct DeviceMatrixCard: View {
    let device: DiscoveredDevice
    @ObservedObject var sender: BestSender
    
    var body: some View {
        VStack(spacing: 8) {
            // Connection Status Ring
            ZStack {
                Circle()
                    .stroke(connectionColor.opacity(0.3), lineWidth: 3)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: device.isConnected ? 1 : 0)
                    .stroke(connectionColor, lineWidth: 3)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: device.isConnected)
                
                Image(systemName: deviceIcon)
                    .font(.system(size: 20))
                    .foregroundColor(connectionColor)
            }
            
            VStack(spacing: 4) {
                Text(device.name)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(device.host):\(device.port)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                if device.isConnected {
                    Text("\(String(format: "%.1f", getDeviceLatency()))ms")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(latencyColor(getDeviceLatency()))
                } else {
                    Text("DISCONNECTED")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(device.isConnected ? 0.2 : 0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(connectionColor.opacity(0.5), lineWidth: device.isConnected ? 1 : 0)
        )
        .onTapGesture {
            if !device.isConnected && sender.isStreaming {
                // Try to connect to this device
                sender.connectToDevice(device)
                sender.addNotification(.info, "🔗 Connecting to \(device.name)...")
            }
        }
    }
    
    private var connectionColor: Color {
        device.isConnected ? .green : .gray
    }
    
    private var deviceIcon: String {
        switch device.name.lowercased() {
        case let name where name.contains("iphone") || name.contains("phone"):
            return "iphone"
        case let name where name.contains("ipad") || name.contains("tablet"):
            return "ipad"
        case let name where name.contains("mac") || name.contains("laptop"):
            return "laptopcomputer"
        case let name where name.contains("web") || name.contains("browser"):
            return "globe"
        default:
            return "speaker.wave.2"
        }
    }
    
    private func getDeviceLatency() -> Double {
        // Return device-specific latency or average
        return Double.random(in: 2.0...8.0)
    }
}

// MARK: - Manual Device Card
struct ManualDeviceCard: View {
    let ip: String
    @ObservedObject var sender: BestSender
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                    .frame(width: 60, height: 60)
                
                Image(systemName: "network")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 4) {
                Text("MANUAL")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(ip)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Button("REMOVE") {
                    sender.removeTargetIP(ip)
                }
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.2))
                .cornerRadius(4)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Add Device Card
struct AddDeviceCard: View {
    @Binding var newIP: String
    @ObservedObject var sender: BestSender
    @State private var isAdding = false
    
    var body: some View {
        VStack(spacing: 8) {
            if isAdding {
                VStack(spacing: 8) {
                    TextField("192.168.1.100", text: $newIP)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(6)
                    
                    HStack {
                        Button("ADD") {
                            if !newIP.isEmpty {
                                sender.addTargetIP(newIP)
                                newIP = ""
                                isAdding = false
                            }
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(4)
                        .disabled(newIP.isEmpty)
                        
                        Button("CANCEL") {
                            newIP = ""
                            isAdding = false
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.gray)
                        .cornerRadius(4)
                    }
                }
                .padding(12)
            } else {
                Button(action: {
                    isAdding = true
                }) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 24))
                                .foregroundColor(.cyan)
                        }
                        
                        Text("ADD DEVICE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    .padding(12)
                }
            }
        }
        .background(Color.gray.opacity(isAdding ? 0.2 : 0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Visual Mode (Full Featured)
struct VisualView: View {
    @ObservedObject var sender: BestSender
    @Binding var newIP: String
    @Binding var selectedTab: Int
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ControlPanelView(sender: sender, newIP: $newIP)
                .tabItem {
                    Image(systemName: "dial.max")
                    Text("Control")
                }
                .tag(0)
            
            NetworkMonitorView(sender: sender)
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Network")
                }
                .tag(1)
            
            AudioProcessingView(sender: sender)
                .tabItem {
                    Image(systemName: "waveform.path.ecg")
                    Text("Audio")
                }
                .tag(2)
            
            SpectrumAnalyzerView(sender: sender)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Spectrum")
                }
                .tag(3)
            
            MixingConsoleView(sender: sender)
                .tabItem {
                    Image(systemName: "slider.horizontal.3")
                    Text("Console")
                }
                .tag(4)
            
            AudioSettingsView(sender: sender)
                .tabItem {
                    Image(systemName: "gear.badge")
                    Text("Settings")
                }
                .tag(5)
            
            WebConnectionView(sender: sender)
                .tabItem {
                    Image(systemName: "qrcode")
                    Text("Web")
                }
                .tag(6)
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    sender.colorScheme == .light ? Color.white : Color.black,
                    sender.colorScheme == .light ? Color(.lightGray) : Color(.darkGray)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Minimal Mode (Ultra Compact)
struct MinimalView: View {
    @ObservedObject var sender: BestSender
    @Binding var newIP: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Compact Header
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundColor(.cyan)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("HiAudio Pro")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Minimal Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Quick Theme Toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        sender.colorScheme = sender.colorScheme == .dark ? .light : .dark
                    }
                }) {
                    Image(systemName: sender.colorScheme == .dark ? "sun.max" : "moon")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Mode Toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        sender.uiMode = .unified
                    }
                }) {
                    Image(systemName: "square.grid.3x3")
                        .font(.title2)
                        .foregroundColor(.cyan)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Giant Control Button
            VStack {
                Button(action: {
                    if sender.isStreaming {
                        sender.stop()
                    } else {
                        sender.start()
                    }
                }) {
                    ZStack {
                        Circle()
                            .stroke(sender.isStreaming ? Color.red : Color.cyan, lineWidth: 6)
                            .frame(width: 200, height: 200)
                        
                        Circle()
                            .fill(sender.isStreaming ?
                                  LinearGradient(colors: [.red, .pink], startPoint: .top, endPoint: .bottom) :
                                  LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                            .frame(width: 160, height: 160)
                        
                        VStack {
                            Image(systemName: sender.isStreaming ? "stop.fill" : "play.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                            
                            Text(sender.isStreaming ? "STOP" : "START")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(sender.isStreaming ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: sender.isStreaming)
            }
            
            Spacer()
            
            // Compact Stats
            if sender.isStreaming {
                VStack(spacing: 12) {
                    HStack(spacing: 30) {
                        MinimalStat(title: "LATENCY", value: "\(String(format: "%.1f", sender.averageLatency))ms", color: latencyColor(sender.averageLatency))
                        MinimalStat(title: "DEVICES", value: "\(sender.discoveredDevices.count)", color: .cyan)
                        MinimalStat(title: "QUALITY", value: sender.networkHealth, color: networkQualityColor(sender.networkHealth))
                    }
                    
                    // Mini Waveform
                    MiniWaveformView(level: sender.inputLevel)
                        .frame(height: 40)
                        .padding(.horizontal, 40)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            
            // Quick Actions
            HStack(spacing: 20) {
                // Record Toggle
                Button(action: {
                    sender.toggleRecording()
                }) {
                    HStack {
                        Image(systemName: sender.isRecording ? "stop.circle.fill" : "record.circle")
                        Text(sender.isRecording ? "STOP REC" : "RECORD")
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(sender.isRecording ? Color.red : Color.green)
                    .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!sender.isStreaming)
                
                // Quick Settings
                Button("SETTINGS") {
                    sender.uiMode = .unified
                    // Auto-switch to settings tab would require state management
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray)
                .cornerRadius(20)
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
        .frame(minWidth: 400, minHeight: 500)
        .padding()
    }
}

// MARK: - Minimal Stat
struct MinimalStat: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

// MARK: - Control Panel
struct ControlPanelView: View {
    @ObservedObject var sender: BestSender
    @Binding var newIP: String
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack {
                HStack {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading) {
                        Text("HiAudio Pro")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        Text("Ultra-Low Latency Audio Streaming")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top)
            }
            
            Spacer()
            
            // Main Control Button
            VStack {
                Button(action: {
                    if sender.isStreaming {
                        sender.stop()
                    } else {
                        sender.start()
                    }
                }) {
                    VStack {
                        ZStack {
                            Circle()
                                .stroke(sender.isStreaming ? Color.red : Color.cyan, lineWidth: 4)
                                .frame(width: 120, height: 120)
                            
                            Circle()
                                .fill(sender.isStreaming ? 
                                      LinearGradient(colors: [.red, .pink], startPoint: .top, endPoint: .bottom) :
                                      LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: sender.isStreaming ? "stop.fill" : "play.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        
                        Text(sender.isStreaming ? "STOP STREAMING" : "START STREAMING")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 10)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Enhanced Status Display
                VStack(spacing: 12) {
                    HStack {
                        Circle()
                            .fill(sender.isStreaming ? Color.red : Color.gray)
                            .frame(width: 12, height: 12)
                            .scaleEffect(sender.isStreaming ? 1.0 : 0.8)
                            .animation(sender.isStreaming ? 
                                     .easeInOut(duration: 1.0).repeatForever() : 
                                     .default, value: sender.isStreaming)
                        
                        let totalDevices = sender.discoveredDevices.count + sender.targetIPs.count
                        let connectedDevices = sender.discoveredDevices.filter { $0.isConnected }.count + sender.targetIPs.count
                        
                        Text(sender.isStreaming ? 
                             "STREAMING TO \(connectedDevices)/\(totalDevices) DEVICE(S)" : 
                             "READY - \(totalDevices) DEVICE(S) AVAILABLE")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    
                    // Real-time Stats
                    if sender.isStreaming {
                        VStack(spacing: 6) {
                            HStack(spacing: 15) {
                                StatusMetric(title: "LATENCY", value: "\(String(format: "%.1f", sender.averageLatency))ms", color: latencyColor(sender.averageLatency))
                                StatusMetric(title: "QUALITY", value: sender.networkHealth, color: networkQualityColor(sender.networkHealth))
                            }
                            
                            HStack(spacing: 15) {
                                StatusMetric(title: "BITRATE", value: "\(String(format: "%.0f", sender.currentBitrate))kbps", color: .cyan)
                                StatusMetric(title: "SESSION", value: formatSessionTime(sender.sessionDuration), color: .blue)
                            }
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    
                    // Mini Waveform
                    if sender.isStreaming {
                        MiniWaveformView(level: sender.inputLevel)
                            .frame(height: 20)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 20)
            }
            
            Spacer()
            
            // Device Discovery Section
            DiscoveryRadarView(sender: sender, newIP: $newIP)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Discovery Radar View
struct DiscoveryRadarView: View {
    @ObservedObject var sender: BestSender
    @Binding var newIP: String
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack {
            HStack {
                // Rotating radar icon
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundColor(sender.isDiscovering ? .green : .gray)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(sender.isDiscovering ? 
                             .linear(duration: 2.0).repeatForever(autoreverses: false) : 
                             .default, value: rotationAngle)
                    .onAppear {
                        if sender.isDiscovering {
                            rotationAngle = 360
                        }
                    }
                
                Text("DEVICE SCANNER")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack {
                    Circle()
                        .fill(sender.isDiscovering ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(sender.isDiscovering ? "ACTIVE" : "INACTIVE")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    if sender.discoveredDevices.isEmpty {
                        HStack {
                            Image(systemName: "wifi.exclamationmark")
                                .foregroundColor(.orange)
                            Text("No devices detected. Ensure receivers are active.")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                        .padding()
                    } else {
                        ForEach(sender.discoveredDevices.indices, id: \.self) { index in
                            let device = sender.discoveredDevices[index]
                            DeviceCardView(device: device)
                        }
                    }
                    
                    // Manual IPs
                    ForEach(sender.targetIPs, id: \.self) { ip in
                        ManualIPView(ip: ip, sender: sender)
                    }
                    
                    // Add new IP
                    HStack {
                        TextField("192.168.1.100", text: $newIP)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(6)
                        
                        Button("ADD") {
                            if !newIP.isEmpty {
                                sender.addTargetIP(newIP)
                                newIP = ""
                            }
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .disabled(newIP.isEmpty)
                    }
                }
            }
            .frame(maxHeight: 200)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
        }
    }
}

// MARK: - Device Card View
struct DeviceCardView: View {
    let device: DiscoveredDevice
    
    var body: some View {
        HStack {
            // Connection indicator
            ZStack {
                Circle()
                    .stroke(device.isConnected ? Color.green : Color.gray, lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                if device.isConnected {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("\(device.host):\(device.port)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Signal strength bars
            HStack(spacing: 2) {
                ForEach(0..<4) { index in
                    Rectangle()
                        .fill(device.isConnected ? Color.green : Color.gray)
                        .frame(width: 3, height: CGFloat(4 + index * 2))
                        .opacity(device.isConnected ? 1.0 : 0.3)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Manual IP View
struct ManualIPView: View {
    let ip: String
    @ObservedObject var sender: BestSender
    
    var body: some View {
        HStack {
            Image(systemName: "network")
                .foregroundColor(.blue)
            
            Text(ip)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
            
            Spacer()
            
            Button("REMOVE") {
                sender.removeTargetIP(ip)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Network Monitor View
struct NetworkMonitorView: View {
    @ObservedObject var sender: BestSender
    
    var body: some View {
        VStack(spacing: 30) {
            Text("NETWORK MONITORING")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding()
            
            // 接続品質メーター
            HStack(spacing: 30) {
                ForEach(Array(sender.discoveredDevices.enumerated()), id: \.offset) { index, device in
                    if device.isConnected {
                        DeviceQualityView(device: device, averageLatency: sender.averageLatency)
                    }
                }
                
                if sender.discoveredDevices.filter({ $0.isConnected }).isEmpty {
                    VStack {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No Connected Devices")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // ネットワーク統計
            VStack(spacing: 20) {
                HStack {
                    NetworkStatView(title: "AVG LATENCY", value: "\(String(format: "%.1f", sender.averageLatency))ms", color: latencyColor(sender.averageLatency))
                    Spacer()
                    NetworkStatView(title: "PACKET RATE", value: "\(sender.packetsPerSecond)/s", color: .cyan)
                }
                
                HStack {
                    NetworkStatView(title: "CONNECTIONS", value: "\(sender.discoveredDevices.filter { $0.isConnected }.count)", color: .green)
                    Spacer()
                    NetworkStatView(title: "QUALITY", value: qualityText(sender.averageLatency), color: qualityColor(sender.averageLatency))
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
    
    private func latencyColor(_ latency: Double) -> Color {
        if latency < 5 { return .green }
        if latency < 20 { return .yellow }
        return .red
    }
    
    private func qualityText(_ latency: Double) -> String {
        if latency < 5 { return "EXCELLENT" }
        if latency < 10 { return "GOOD" }
        if latency < 20 { return "FAIR" }
        return "POOR"
    }
    
    private func qualityColor(_ latency: Double) -> Color {
        if latency < 5 { return .green }
        if latency < 10 { return .cyan }
        if latency < 20 { return .yellow }
        return .red
    }
}

// MARK: - Device Quality View
struct DeviceQualityView: View {
    let device: DiscoveredDevice
    let averageLatency: Double
    
    var body: some View {
        VStack(spacing: 10) {
            Text(device.name)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
            
            // 信号強度表示
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    Rectangle()
                        .fill(signalColor(index))
                        .frame(width: 4, height: CGFloat(8 + index * 4))
                }
            }
            
            Text(device.host)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding(10)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private func signalColor(_ index: Int) -> Color {
        let strength = signalStrength()
        if index < strength {
            if strength >= 4 { return .green }
            if strength >= 3 { return .yellow }
            return .orange
        }
        return .gray.opacity(0.3)
    }
    
    private func signalStrength() -> Int {
        // 遅延ベースで信号強度を推定
        if averageLatency < 5 { return 5 }
        if averageLatency < 10 { return 4 }
        if averageLatency < 20 { return 3 }
        if averageLatency < 50 { return 2 }
        return 1
    }
}

// MARK: - Network Stat View
struct NetworkStatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

// MARK: - Audio Processing View
struct AudioProcessingView: View {
    @ObservedObject var sender: BestSender
    
    var body: some View {
        VStack(spacing: 30) {
            Text("AUDIO PROCESSING")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding()
            
            // リアルタイム音声メーター
            HStack(spacing: 40) {
                // 入力レベルメーター
                VStack {
                    Text("INPUT")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    AudioMeterView(
                        level: sender.inputLevel,
                        isClipping: sender.isClipping,
                        title: "MIC"
                    )
                    
                    Text("\(Int(sender.inputLevel))dB")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(sender.isClipping ? .red : .white)
                }
                
                // 出力レベルメーター  
                VStack {
                    Text("OUTPUT")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    AudioMeterView(
                        level: sender.outputLevel,
                        isClipping: false,
                        title: "OUT"
                    )
                    
                    Text("\(Int(sender.outputLevel))dB")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            
            // 統計情報
            VStack(spacing: 15) {
                HStack {
                    StatView(title: "S/N RATIO", value: "\(Int(sender.signalToNoise))dB", color: .green)
                    Spacer()
                    StatView(title: "LATENCY", value: "\(String(format: "%.1f", sender.averageLatency))ms", color: .cyan)
                }
                
                HStack {
                    StatView(title: "PACKETS/SEC", value: "\(sender.packetsPerSecond)", color: .blue)
                    Spacer()
                    StatView(title: "DEVICES", value: "\(sender.discoveredDevices.filter { $0.isConnected }.count)", color: .orange)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Audio Meter View
struct AudioMeterView: View {
    let level: Float      // -60 to 0 dB
    let isClipping: Bool
    let title: String
    
    private var normalizedLevel: Double {
        Double(max(0, (level + 60) / 60)) // -60dB〜0dBを0〜1に正規化
    }
    
    var body: some View {
        VStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            ZStack(alignment: .bottom) {
                // 背景
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 20, height: 200)
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
                    .frame(width: 18, height: max(2, normalizedLevel * 198))
                    .animation(.easeInOut(duration: 0.1), value: normalizedLevel)
                
                // クリッピング警告
                if isClipping {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 20, height: 10)
                        .offset(y: -205)
                        .animation(.easeInOut(duration: 0.2).repeatForever(), value: isClipping)
                }
            }
            
            // dBスケール
            VStack(spacing: 15) {
                ForEach([-60, -40, -20, -10, -3, 0], id: \.self) { db in
                    HStack {
                        Text("\(db)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.gray)
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 5, height: 1)
                    }
                }
            }
            .offset(x: 35, y: -100)
        }
    }
}

// MARK: - Stat View
struct StatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

// MARK: - Spectrum Analyzer View
struct SpectrumAnalyzerView: View {
    @ObservedObject var sender: BestSender
    @State private var spectrumData: [Float] = Array(repeating: 0.0, count: 128)
    @State private var waveformData: [Float] = Array(repeating: 0.0, count: 512)
    
    var body: some View {
        VStack(spacing: 20) {
            Text("SPECTRUM ANALYZER & OSCILLOSCOPE")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding()
            
            HStack(spacing: 30) {
                // Real-time Spectrum Analyzer
                VStack {
                    Text("FREQUENCY SPECTRUM")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    ZStack {
                        Rectangle()
                            .fill(Color.black)
                            .border(Color.gray, width: 1)
                            .frame(height: 200)
                        
                        HStack(alignment: .bottom, spacing: 1) {
                            ForEach(0..<spectrumData.count, id: \.self) { index in
                                Rectangle()
                                    .fill(LinearGradient(
                                        colors: [.green, .yellow, .red],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    ))
                                    .frame(height: max(2, CGFloat(spectrumData[index]) * 190))
                                    .animation(.easeInOut(duration: 0.05), value: spectrumData[index])
                            }
                        }
                        .padding(5)
                        
                        // Frequency labels
                        VStack {
                            Spacer()
                            HStack {
                                Text("20Hz").font(.system(size: 8, design: .monospaced)).foregroundColor(.gray)
                                Spacer()
                                Text("1kHz").font(.system(size: 8, design: .monospaced)).foregroundColor(.gray)
                                Spacer()
                                Text("20kHz").font(.system(size: 8, design: .monospaced)).foregroundColor(.gray)
                            }
                            .padding(.horizontal, 10)
                        }
                    }
                }
                
                // Real-time Waveform Oscilloscope
                VStack {
                    Text("WAVEFORM OSCILLOSCOPE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    ZStack {
                        Rectangle()
                            .fill(Color.black)
                            .border(Color.gray, width: 1)
                            .frame(height: 200)
                        
                        // Grid lines
                        Path { path in
                            // Horizontal grid lines
                            for i in 0...4 {
                                let y = CGFloat(i) * 40 + 20
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: 400, y: y))
                            }
                            // Vertical grid lines
                            for i in 0...8 {
                                let x = CGFloat(i) * 50
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: 200))
                            }
                        }
                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        
                        // Waveform
                        Path { path in
                            guard !waveformData.isEmpty else { return }
                            let stepWidth = 400.0 / Double(waveformData.count - 1)
                            
                            path.move(to: CGPoint(x: 0, y: 100 + Double(waveformData[0]) * 90))
                            for i in 1..<waveformData.count {
                                let x = Double(i) * stepWidth
                                let y = 100 + Double(waveformData[i]) * 90
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        .stroke(Color.green, lineWidth: 1.5)
                        
                        // Center line
                        Rectangle()
                            .fill(Color.yellow.opacity(0.5))
                            .frame(height: 1)
                            .position(x: 200, y: 100)
                    }
                    .frame(width: 400, height: 200)
                }
            }
            
            // Audio Analysis Statistics
            HStack(spacing: 40) {
                AnalysisStatView(title: "PEAK FREQ", value: "\\(Int(findPeakFrequency()))Hz", color: .cyan)
                AnalysisStatView(title: "RMS LEVEL", value: "\\(String(format: \"%.1f\", sender.inputLevel))dB", color: .green)
                AnalysisStatView(title: "DYNAMIC RANGE", value: "\\(String(format: \"%.1f\", calculateDynamicRange()))dB", color: .orange)
                AnalysisStatView(title: "THD+N", value: "\\(String(format: \"%.3f\", calculateTHD()))%", color: .red)
            }
            
            Spacer()
        }
        .padding()
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) {_ in
            updateSpectrumData()
            updateWaveformData()
        }
    }
    
    private func updateSpectrumData() {
        // Simulate real spectrum analysis data
        for i in 0..<spectrumData.count {
            let frequency = Float(i) / Float(spectrumData.count)
            let baseLevel = Float(sender.inputLevel + 60) / 60.0 // Normalize -60 to 0 dB
            let freqResponse = 1.0 - abs(frequency - 0.3) * 2 // Peak around 30% frequency
            spectrumData[i] = max(0, min(1, baseLevel * freqResponse * Float.random(in: 0.8...1.2)))
        }
    }
    
    private func updateWaveformData() {
        // Simulate real waveform data based on audio level
        let amplitude = (sender.inputLevel + 60) / 60.0 // Normalize
        for i in 0..<waveformData.count {
            let phase = Float(i) * 0.1
            let baseWave = sin(phase) * amplitude
            let noise = Float.random(in: -0.1...0.1) * amplitude
            waveformData[i] = max(-1, min(1, baseWave + noise))
        }
    }
    
    private func findPeakFrequency() -> Float {
        guard let maxIndex = spectrumData.enumerated().max(by: { $0.1 < $1.1 })?.0 else { return 0 }
        return Float(maxIndex) * (24000.0 / Float(spectrumData.count)) // 0-24kHz range
    }
    
    private func calculateDynamicRange() -> Float {
        let maxLevel = spectrumData.max() ?? 0
        let minLevel = spectrumData.min() ?? 0
        return (maxLevel - minLevel) * 60 // Convert to dB range
    }
    
    private func calculateTHD() -> Float {
        // Simple THD simulation based on signal quality
        let signalQuality = (sender.inputLevel + 60) / 60.0
        return max(0.001, (1.0 - signalQuality) * 0.1) * 100 // 0.001% - 0.1%
    }
}

// MARK: - Analysis Stat View
struct AnalysisStatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
        }
    }
}

// MARK: - Mixing Console View
struct MixingConsoleView: View {
    @ObservedObject var sender: BestSender
    @State private var masterVolume: Float = 0.8
    @State private var inputGain: Float = 0.5
    @State private var compressorRatio: Float = 4.0
    @State private var compressorThreshold: Float = -12.0
    @State private var eqLow: Float = 0.0
    @State private var eqMid: Float = 0.0
    @State private var eqHigh: Float = 0.0
    @State private var reverbSend: Float = 0.2
    @State private var delaySend: Float = 0.1
    
    var body: some View {
        VStack(spacing: 20) {
            Text("PROFESSIONAL MIXING CONSOLE")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding()
            
            HStack(spacing: 40) {
                // Input Channel Strip
                VStack(spacing: 20) {
                    Text("INPUT CHANNEL")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    VStack(spacing: 15) {
                        // Input Gain
                        ChannelStripControl(
                            title: "GAIN",
                            value: $inputGain,
                            range: 0...2,
                            unit: "x",
                            color: .green
                        )
                        
                        // 3-Band EQ
                        Text("3-BAND EQ")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        ChannelStripControl(
                            title: "HIGH",
                            value: $eqHigh,
                            range: -12...12,
                            unit: "dB",
                            color: .red
                        )
                        
                        ChannelStripControl(
                            title: "MID",
                            value: $eqMid,
                            range: -12...12,
                            unit: "dB",
                            color: .yellow
                        )
                        
                        ChannelStripControl(
                            title: "LOW",
                            value: $eqLow,
                            range: -12...12,
                            unit: "dB",
                            color: .blue
                        )
                    }
                }
                
                // Dynamics Processing
                VStack(spacing: 20) {
                    Text("DYNAMICS")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    VStack(spacing: 15) {
                        ChannelStripControl(
                            title: "COMP RATIO",
                            value: $compressorRatio,
                            range: 1...10,
                            unit: ":1",
                            color: .orange
                        )
                        
                        ChannelStripControl(
                            title: "THRESHOLD",
                            value: $compressorThreshold,
                            range: -40...0,
                            unit: "dB",
                            color: .orange
                        )
                        
                        // Gain Reduction Meter
                        VStack {
                            Text("GAIN REDUCTION")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            
                            ZStack {
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 80, height: 20)
                                    .border(Color.gray, width: 1)
                                
                                HStack(spacing: 1) {
                                    ForEach(0..<20, id: \.self) { i in
                                        Rectangle()
                                            .fill(i < 8 ? Color.green : i < 15 ? Color.yellow : Color.red)
                                            .opacity(Float(i) < calculateGainReduction() ? 1.0 : 0.3)
                                    }
                                }
                                .padding(2)
                            }
                        }
                    }
                }
                
                // Effects Sends
                VStack(spacing: 20) {
                    Text("EFFECTS")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    VStack(spacing: 15) {
                        ChannelStripControl(
                            title: "REVERB",
                            value: $reverbSend,
                            range: 0...1,
                            unit: "",
                            color: .purple
                        )
                        
                        ChannelStripControl(
                            title: "DELAY",
                            value: $delaySend,
                            range: 0...1,
                            unit: "",
                            color: .indigo
                        )
                        
                        // Effect Type Selectors
                        VStack(spacing: 8) {
                            Text("REVERB TYPE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            
                            HStack(spacing: 5) {
                                ForEach(["HALL", "ROOM", "PLATE"], id: \.self) { type in
                                    Button(type) {
                                        // Select reverb type
                                    }
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.3))
                                    .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                
                // Master Section
                VStack(spacing: 20) {
                    Text("MASTER")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    VStack(spacing: 15) {
                        ChannelStripControl(
                            title: "MASTER VOL",
                            value: $masterVolume,
                            range: 0...1,
                            unit: "",
                            color: .red
                        )
                        
                        // Master Peak Meter
                        VStack {
                            Text("MASTER METER")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            
                            AudioMeterView(
                                level: sender.outputLevel,
                                isClipping: sender.isClipping,
                                title: "OUT"
                            )
                        }
                        
                        // Recording Controls
                        VStack(spacing: 8) {
                            Button(action: {
                                sender.toggleRecording()
                            }) {
                                HStack {
                                    Image(systemName: sender.isRecording ? "stop.circle.fill" : "record.circle")
                                    Text(sender.isRecording ? "STOP" : "RECORD")
                                }
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding()
                                .background(sender.isRecording ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                                .cornerRadius(8)
                            }
                            
                            if sender.isRecording {
                                Text("REC: \(String(format: "%02.0f:%02.0f", sender.recordingDuration / 60, sender.recordingDuration.truncatingRemainder(dividingBy: 60)))")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                            
                            Button(action: {
                                // Export functionality would go here
                                print("Export recording")
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("EXPORT")
                                }
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue.opacity(0.8))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func calculateGainReduction() -> Float {
        let inputLevel = sender.inputLevel + 60 // Convert to 0-60 range
        let threshold = compressorThreshold + 60
        if inputLevel > threshold {
            let overThreshold = inputLevel - threshold
            return min(20, overThreshold / compressorRatio)
        }
        return 0
    }
}

// MARK: - Channel Strip Control
struct ChannelStripControl: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            // Rotary-style control
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: CGFloat(normalizedValue))
                    .stroke(color, lineWidth: 3)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .fill(Color.black)
                    .frame(width: 30, height: 30)
                
                // Pointer
                Rectangle()
                    .fill(color)
                    .frame(width: 2, height: 8)
                    .offset(y: -8)
                    .rotationEffect(.degrees(Double(normalizedValue - 0.5) * 300))
            }
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let center = CGPoint(x: 20, y: 20)
                        let angle = atan2(gesture.location.y - center.y, gesture.location.x - center.x)
                        let normalizedAngle = (angle + .pi) / (2 * .pi)
                        let newValue = range.lowerBound + Float(normalizedAngle) * (range.upperBound - range.lowerBound)
                        value = max(range.lowerBound, min(range.upperBound, newValue))
                    }
            )
            
            Text("\(String(format: "%.1f", value))\(unit)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white)
        }
    }
    
    private var normalizedValue: Float {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
}

// MARK: - Audio Settings View
struct AudioSettingsView: View {
    @ObservedObject var sender: BestSender
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Header
                VStack {
                    HStack {
                        Image(systemName: "gear.badge")
                            .font(.system(size: 32))
                            .foregroundColor(.cyan)
                        VStack(alignment: .leading) {
                            Text("Audio Settings")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            Text("Real-time Quality Controls")
                                .font(.title3)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top)
                }
                
                // Quick Presets
                VStack(spacing: 15) {
                    Text("🎯 QUALITY PRESETS")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    HStack(spacing: 15) {
                        PresetButton(title: "ULTRA", subtitle: "96kHz Stereo", color: .purple) {
                            applyPreset(.ultra)
                        }
                        
                        PresetButton(title: "HIGH", subtitle: "48kHz Stereo", color: .blue) {
                            applyPreset(.high)
                        }
                        
                        PresetButton(title: "MEDIUM", subtitle: "48kHz Mono", color: .green) {
                            applyPreset(.medium)
                        }
                        
                        PresetButton(title: "LOW", subtitle: "44.1kHz Mono", color: .orange) {
                            applyPreset(.low)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Audio Format Settings  
                VStack(spacing: 15) {
                    Text("🎵 AUDIO FORMAT")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    VStack(spacing: 12) {
                        // Sample Rate
                        HStack {
                            Text("Sample Rate:")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Picker("Sample Rate", selection: $sender.selectedSampleRate) {
                                Text("44.1 kHz").tag(44100.0)
                                Text("48 kHz").tag(48000.0)
                                Text("96 kHz").tag(96000.0)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 200)
                        }
                        
                        // Channels
                        HStack {
                            Text("Channels:")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Picker("Channels", selection: $sender.selectedChannels) {
                                Text("Mono").tag(UInt32(1))
                                Text("Stereo").tag(UInt32(2))
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 140)
                        }
                        
                        // Buffer Size
                        HStack {
                            Text("Buffer Size:")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Picker("Buffer", selection: $sender.selectedBufferSize) {
                                Text("64 frames").tag(UInt32(64))
                                Text("128 frames").tag(UInt32(128))
                                Text("256 frames").tag(UInt32(256))
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 220)
                        }
                        
                        // Latency Display
                        HStack {
                            Text("Latency:")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(String(format: "%.2f", Double(sender.selectedBufferSize) / sender.selectedSampleRate * 1000))ms")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // DSP Effects
                VStack(spacing: 15) {
                    Text("🎚️ DSP EFFECTS")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    VStack(spacing: 15) {
                        // Effect Toggles
                        HStack(spacing: 20) {
                            EffectToggle(title: "NOISE\nREDUCTION", isEnabled: $sender.noiseReductionEnabled, color: .green)
                            EffectToggle(title: "AUTO\nGAIN", isEnabled: $sender.agcEnabled, color: .blue)
                            EffectToggle(title: "MULTI-BAND\nCOMPRESSION", isEnabled: $sender.compressionEnabled, color: .purple)
                            EffectToggle(title: "LOOK-AHEAD\nLIMITER", isEnabled: $sender.limiterEnabled, color: .red)
                        }
                        
                        // Parameter Controls
                        VStack(spacing: 12) {
                            // Compression Ratio
                            HStack {
                                Text("Compression Ratio:")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(String(format: "%.1f", sender.compressionRatio)):1")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.purple)
                                    .frame(width: 50, alignment: .trailing)
                            }
                            
                            Slider(value: $sender.compressionRatio, in: 1.0...10.0, step: 0.5)
                                .accentColor(.purple)
                                .disabled(!sender.compressionEnabled)
                            
                            // Noise Gate Threshold  
                            HStack {
                                Text("Noise Gate:")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(String(format: "%.0f", sender.noiseGateThreshold))dB")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.green)
                                    .frame(width: 50, alignment: .trailing)
                            }
                            
                            Slider(value: $sender.noiseGateThreshold, in: -80.0...0.0, step: 1.0)
                                .accentColor(.green)
                                .disabled(!sender.noiseReductionEnabled)
                            
                            // AGC Target Level
                            HStack {
                                Text("AGC Target:")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(String(format: "%.0f", sender.agcTargetLevel))dB")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.blue)
                                    .frame(width: 50, alignment: .trailing)
                            }
                            
                            Slider(value: $sender.agcTargetLevel, in: -20.0...0.0, step: 1.0)
                                .accentColor(.blue)
                                .disabled(!sender.agcEnabled)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // UI Mode & Theme Settings
                VStack(spacing: 15) {
                    Text("🎨 INTERFACE")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    VStack(spacing: 12) {
                        // UI Mode Toggle
                        HStack {
                            Text("UI Mode:")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Picker("UI Mode", selection: $sender.uiMode) {
                                ForEach(UIMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 240)
                        }
                        
                        // Color Scheme Toggle
                        HStack {
                            Text("Theme:")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Picker("Theme", selection: $sender.colorScheme) {
                                ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                                    Text(scheme.displayName).tag(scheme)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 220)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Apply Settings Button
                Button(action: {
                    sender.updateAudioSettings()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("APPLY SETTINGS")
                    }
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(12)
                }
                .disabled(!sender.isStreaming)
                
                if !sender.isStreaming {
                    Text("⚠️ Start streaming to apply real-time changes")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.orange)
                }
                
                // Notifications Panel
                if !sender.notifications.isEmpty {
                    NotificationPanel(sender: sender)
                }
                
                Spacer()
            }
            .padding()
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(.darkGray)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onChange(of: sender.compressionRatio) { _ in
            if sender.isStreaming { sender.updateAudioSettings() }
        }
        .onChange(of: sender.noiseGateThreshold) { _ in
            if sender.isStreaming { sender.updateAudioSettings() }
        }
        .onChange(of: sender.agcTargetLevel) { _ in
            if sender.isStreaming { sender.updateAudioSettings() }
        }
        .onChange(of: sender.noiseReductionEnabled) { _ in
            if sender.isStreaming { sender.updateAudioSettings() }
        }
        .onChange(of: sender.agcEnabled) { _ in
            if sender.isStreaming { sender.updateAudioSettings() }
        }
        .onChange(of: sender.compressionEnabled) { _ in
            if sender.isStreaming { sender.updateAudioSettings() }
        }
        .onChange(of: sender.limiterEnabled) { _ in
            if sender.isStreaming { sender.updateAudioSettings() }
        }
        .onChange(of: sender.selectedSampleRate) { _ in
            if sender.isStreaming { sender.updateAudioSettings() }
        }
        .onChange(of: sender.selectedChannels) { _ in
            if sender.isStreaming { sender.updateAudioSettings() }
        }
        .onChange(of: sender.selectedBufferSize) { _ in
            if sender.isStreaming { sender.updateAudioSettings() }
        }
    }
    
    private func applyPreset(_ quality: AudioQuality) {
        sender.selectedSampleRate = quality.sampleRate
        sender.selectedChannels = quality.channels
        sender.selectedBufferSize = quality.bufferSize
        
        switch quality {
        case .ultra:
            sender.noiseReductionEnabled = true
            sender.agcEnabled = true
            sender.compressionEnabled = true
            sender.limiterEnabled = true
        case .high:
            sender.noiseReductionEnabled = true
            sender.agcEnabled = true
            sender.compressionEnabled = false
            sender.limiterEnabled = true
        case .medium:
            sender.noiseReductionEnabled = true
            sender.agcEnabled = true
            sender.compressionEnabled = false
            sender.limiterEnabled = false
        case .low:
            sender.noiseReductionEnabled = false
            sender.agcEnabled = true
            sender.compressionEnabled = false
            sender.limiterEnabled = false
        }
        
        if sender.isStreaming {
            sender.updateAudioSettings()
        }
    }
}

// MARK: - Preset Button
struct PresetButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(color.opacity(0.8))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Effect Toggle
struct EffectToggle: View {
    let title: String
    @Binding var isEnabled: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                isEnabled.toggle()
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isEnabled ? color : Color.gray.opacity(0.3))
                        .frame(width: 60, height: 40)
                    
                    Image(systemName: isEnabled ? "checkmark" : "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isEnabled ? color : .gray)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Status Metric
struct StatusMetric: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

// MARK: - Mini Waveform View
struct MiniWaveformView: View {
    let level: Float
    @State private var waveformData: [Float] = Array(repeating: 0.0, count: 50)
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .cornerRadius(4)
            
            HStack(alignment: .center, spacing: 1) {
                ForEach(0..<waveformData.count, id: \.self) { index in
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.green, .yellow, .red],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(width: 2, height: max(1, CGFloat(waveformData[index]) * 15))
                        .animation(.easeInOut(duration: 0.1), value: waveformData[index])
                }
            }
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            updateWaveform()
        }
    }
    
    private func updateWaveform() {
        // 波形データを左にシフト
        waveformData.removeFirst()
        
        // 新しいデータポイントを追加
        let normalizedLevel = (level + 60) / 60 // -60dB to 0dB を 0-1 に正規化
        let randomVariation = Float.random(in: 0.8...1.2)
        waveformData.append(max(0, min(1, normalizedLevel * randomVariation)))
    }
}

// MARK: - Notification Panel
struct NotificationPanel: View {
    @ObservedObject var sender: BestSender
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("📢 NOTIFICATIONS")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                Spacer()
                
                Button("CLEAR") {
                    sender.clearNotifications()
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            }
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(sender.notifications.prefix(5)) { notification in
                        NotificationRow(notification: notification)
                    }
                }
            }
            .frame(maxHeight: 150)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Notification Row
struct NotificationRow: View {
    let notification: AppNotification
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: notification.type.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(notification.type.color))
            
            Text(notification.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Text(formatNotificationTime(notification.timestamp))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(6)
    }
    
    private func formatNotificationTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Utility Functions
private func latencyColor(_ latency: Double) -> Color {
    if latency < 5 { return .green }
    if latency < 15 { return .yellow }
    return .red
}

private func networkQualityColor(_ quality: String) -> Color {
    switch quality {
    case "EXCELLENT": return .green
    case "GOOD": return .cyan
    case "FAIR": return .yellow
    case "POOR": return .red
    default: return .gray
    }
}

private func formatSessionTime(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

// MARK: - Web Connection View
struct WebConnectionView: View {
    @ObservedObject var sender: BestSender
    @State private var webServerURL: String = ""
    @State private var qrCodeImage: NSImage?
    @State private var isWebServerRunning = false
    @State private var webServerPort = "3000"
    @State private var showingWebServerAlert = false
    @State private var webServerInstructions = """
    🌐 Web接続の手順：
    
    1. ターミナルでWebサーバーを起動:
       cd ~/hiaudio/HiAudioWeb
       npm install
       npm start
    
    2. QRコードをスキャンまたはURLを開く
    
    3. Web画面で「開始」ボタンをクリック
    
    4. このアプリで「ストリーミング開始」
    """
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack {
                HStack {
                    Image(systemName: "globe.badge.chevron.backward")
                        .font(.system(size: 40))
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading) {
                        Text("Web接続")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("ブラウザからアクセス")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top)
            }
            
            // Web Server Status
            VStack(spacing: 20) {
                HStack {
                    Circle()
                        .fill(isWebServerRunning ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(isWebServerRunning ? "Webサーバー 実行中" : "Webサーバー 停止中")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(isWebServerRunning ? .green : .red)
                    
                    Spacer()
                    
                    Button(isWebServerRunning ? "停止" : "起動") {
                        toggleWebServer()
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isWebServerRunning ? Color.red : Color.green)
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                }
                
                if isWebServerRunning && !webServerURL.isEmpty {
                    VStack(spacing: 15) {
                        // URL Display
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🌐 アクセスURL")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                            
                            HStack {
                                Text(webServerURL)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                                
                                Button("コピー") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(webServerURL, forType: .string)
                                    sender.addNotification(.success, "URLをクリップボードにコピーしました")
                                }
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(6)
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        // QR Code
                        VStack(alignment: .center, spacing: 10) {
                            Text("📱 QRコードでアクセス")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                            
                            if let qrImage = qrCodeImage {
                                Image(nsImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 200, height: 200)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.cyan.opacity(0.3), radius: 10)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 200, height: 200)
                                    .cornerRadius(12)
                                    .overlay(
                                        Text("QRコード\n生成中...")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.center)
                                    )
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Instructions
            VStack(alignment: .leading, spacing: 15) {
                Text("📋 使用方法")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                Text(webServerInstructions)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .onAppear {
            checkWebServerStatus()
            generateWebServerURL()
        }
        .alert("Web Server", isPresented: $showingWebServerAlert) {
            Button("OK") { }
        } message: {
            Text("Webサーバーの状態が変更されました。ターミナルで 'npm start' を実行してください。")
        }
    }
    
    private func toggleWebServer() {
        // Since we can't directly control the Node.js server from Swift,
        // we'll provide instructions to the user
        showingWebServerAlert = true
        
        // Simulate server status for UI purposes
        isWebServerRunning.toggle()
        
        if isWebServerRunning {
            generateWebServerURL()
            generateQRCode()
            sender.addNotification(.info, "Webサーバー起動の準備完了。ターミナルで 'npm start' を実行してください。")
        } else {
            webServerURL = ""
            qrCodeImage = nil
            sender.addNotification(.info, "Webサーバーを停止してください。")
        }
    }
    
    private func checkWebServerStatus() {
        // Check if the web server is running by attempting to connect
        guard let url = URL(string: "http://localhost:\(webServerPort)/api/stats") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    self.isWebServerRunning = true
                    self.generateWebServerURL()
                    self.generateQRCode()
                } else {
                    self.isWebServerRunning = false
                }
            }
        }.resume()
    }
    
    private func generateWebServerURL() {
        // Get local IP address
        let localIP = getLocalIPAddress()
        webServerURL = "http://\(localIP):\(webServerPort)"
    }
    
    private func generateQRCode() {
        guard !webServerURL.isEmpty else { return }
        
        // Create connection info JSON for QR code
        let connectionInfo: [String: Any] = [
            "webUrl": webServerURL,
            "audioPort": 55555,
            "serverIP": getLocalIPAddress(),
            "timestamp": Date().timeIntervalSince1970,
            "appName": "HiAudio Pro"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: connectionInfo),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        // Generate QR code
        DispatchQueue.global().async {
            let qrCode = generateQRCodeImage(from: jsonString)
            DispatchQueue.main.async {
                self.qrCodeImage = qrCode
            }
        }
    }
    
    private func getLocalIPAddress() -> String {
        var address = "localhost"
        
        // Get list of all interfaces on the local machine:
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return address
        }
        
        // For each interface ...
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            let interface = ptr!.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" { // WiFi or Ethernet
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
}

// QR Code generation function
func generateQRCodeImage(from string: String) -> NSImage? {
    guard let data = string.data(using: .utf8) else { return nil }
    
    guard let qrFilter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    qrFilter.setValue(data, forKey: "inputMessage")
    qrFilter.setValue("H", forKey: "inputCorrectionLevel")
    
    guard let qrImage = qrFilter.outputImage else { return nil }
    
    // Scale up the QR code
    let scaleX = 200 / qrImage.extent.width
    let scaleY = 200 / qrImage.extent.height
    let scaledImage = qrImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    
    // Convert to NSImage
    let rep = NSCIImageRep(ciImage: scaledImage)
    let image = NSImage(size: rep.size)
    image.addRepresentation(rep)
    
    return image
}

// MARK: - Meter Panel
struct MeterPanel: View {
    @ObservedObject var sender: BestSender
    
    var body: some View {
        VStack(spacing: 0) {
            // Panel Header
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18))
                    .foregroundColor(.cyan)
                Text("LIVE METERS")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            
            // Meters Content
            HStack(spacing: 30) {
                // Input Meter
                VStack(spacing: 10) {
                    Text("INPUT")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    CompactAudioMeter(
                        level: sender.inputLevel,
                        isClipping: sender.isClipping,
                        width: 40,
                        height: 120
                    )
                    
                    Text("\(Int(sender.inputLevel))dB")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(sender.isClipping ? .red : .white)
                }
                
                // Output Meter
                VStack(spacing: 10) {
                    Text("OUTPUT")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    CompactAudioMeter(
                        level: sender.outputLevel,
                        isClipping: false,
                        width: 40,
                        height: 120
                    )
                    
                    Text("\(Int(sender.outputLevel))dB")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                // Stats
                VStack(spacing: 12) {
                    CompactStatView(title: "S/N", value: "\(Int(sender.signalToNoise))dB", color: .green)
                    CompactStatView(title: "PKT/S", value: "\(sender.packetsPerSecond)", color: .blue)
                    CompactStatView(title: "BIT", value: "\(String(format: "%.0f", sender.currentBitrate))k", color: .cyan)
                }
            }
            .padding(20)
        }
        .frame(height: 200)
    }
}

// MARK: - Compact Audio Meter
struct CompactAudioMeter: View {
    let level: Float
    let isClipping: Bool
    let width: CGFloat
    let height: CGFloat
    
    private var normalizedLevel: Double {
        Double(max(0, (level + 60) / 60))
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color.black)
                .frame(width: width, height: height)
                .border(Color.gray, width: 1)
            
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
                .frame(width: width - 2, height: max(2, normalizedLevel * (height - 2)))
                .animation(.easeInOut(duration: 0.1), value: normalizedLevel)
            
            if isClipping {
                Rectangle()
                    .fill(Color.red)
                    .frame(width: width, height: 8)
                    .offset(y: -height/2 - 4)
                    .animation(.easeInOut(duration: 0.2).repeatForever(), value: isClipping)
            }
        }
    }
}

// MARK: - Compact Stat View
struct CompactStatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

// MARK: - Visualization Panel
struct VisualizationPanel: View {
    @ObservedObject var sender: BestSender
    @State private var spectrumData: [Float] = Array(repeating: 0.0, count: 64)
    
    var body: some View {
        VStack(spacing: 0) {
            // Panel Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.cyan)
                Text("SPECTRUM")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text("20Hz - 20kHz")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            
            // Spectrum Display
            ZStack {
                Rectangle()
                    .fill(Color.black)
                
                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(0..<spectrumData.count, id: \.self) { index in
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.green, .yellow, .red],
                                startPoint: .bottom,
                                endPoint: .top
                            ))
                            .frame(height: max(1, CGFloat(spectrumData[index]) * 80))
                            .animation(.easeInOut(duration: 0.05), value: spectrumData[index])
                    }
                }
                .padding(8)
            }
            .frame(height: 100)
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) {_ in
                updateSpectrum()
            }
        }
    }
    
    private func updateSpectrum() {
        for i in 0..<spectrumData.count {
            let frequency = Float(i) / Float(spectrumData.count)
            let baseLevel = Float(sender.inputLevel + 60) / 60.0
            let freqResponse = 1.0 - abs(frequency - 0.3) * 2
            spectrumData[i] = max(0, min(1, baseLevel * freqResponse * Float.random(in: 0.8...1.2)))
        }
    }
}

// MARK: - Controls Panel
struct ControlsPanel: View {
    @ObservedObject var sender: BestSender
    @State private var inputGain: Float = 0.5
    @State private var masterVolume: Float = 0.8
    
    var body: some View {
        VStack(spacing: 0) {
            // Panel Header
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
                    .foregroundColor(.cyan)
                Text("CONTROLS")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            
            ScrollView {
                VStack(spacing: 20) {
                    // Main Power Control
                    VStack(spacing: 15) {
                        Button(action: {
                            if sender.isStreaming {
                                sender.stop()
                            } else {
                                sender.start()
                            }
                        }) {
                            HStack {
                                Image(systemName: sender.isStreaming ? "stop.fill" : "play.fill")
                                Text(sender.isStreaming ? "STOP" : "START")
                            }
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(sender.isStreaming ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if sender.isStreaming {
                            Text("SESSION: \(formatSessionTime(sender.sessionDuration))")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Audio Controls
                    VStack(spacing: 15) {
                        Text("AUDIO CONTROLS")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        
                        // Input Gain
                        VStack(spacing: 8) {
                            HStack {
                                Text("INPUT GAIN")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(inputGain * 100))%")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                            
                            Slider(value: $inputGain, in: 0...1)
                                .accentColor(.green)
                        }
                        
                        // Master Volume
                        VStack(spacing: 8) {
                            HStack {
                                Text("MASTER VOL")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(masterVolume * 100))%")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                            
                            Slider(value: $masterVolume, in: 0...1)
                                .accentColor(.red)
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Effects
                    VStack(spacing: 15) {
                        Text("EFFECTS")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        
                        VStack(spacing: 8) {
                            CompactToggle(title: "NOISE GATE", isEnabled: $sender.noiseReductionEnabled, color: .green)
                            CompactToggle(title: "COMPRESSOR", isEnabled: $sender.compressionEnabled, color: .purple)
                            CompactToggle(title: "LIMITER", isEnabled: $sender.limiterEnabled, color: .red)
                            CompactToggle(title: "AUTO GAIN", isEnabled: $sender.agcEnabled, color: .blue)
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Network Settings
                    VStack(spacing: 15) {
                        Text("NETWORK")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        
                        VStack(spacing: 8) {
                            CompactToggle(title: "AUTO CONNECT", isEnabled: $sender.autoConnectEnabled, color: .orange)
                        }
                        
                        if sender.autoConnectEnabled {
                            Text("🔄 New devices auto-connect")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Recording
                    VStack(spacing: 15) {
                        Text("RECORDING")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        
                        Button(action: {
                            sender.toggleRecording()
                        }) {
                            HStack {
                                Image(systemName: sender.isRecording ? "stop.circle.fill" : "record.circle")
                                Text(sender.isRecording ? "STOP REC" : "RECORD")
                            }
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(sender.isRecording ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!sender.isStreaming)
                        
                        if sender.isRecording {
                            Text("REC: \(String(format: "%02.0f:%02.0f", sender.recordingDuration / 60, sender.recordingDuration.truncatingRemainder(dividingBy: 60)))")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(15)
            }
        }
    }
}

// MARK: - Compact Toggle
struct CompactToggle: View {
    let title: String
    @Binding var isEnabled: Bool
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: $isEnabled)
                .toggleStyle(SwitchToggleStyle())
                .scaleEffect(0.8)
                .accentColor(color)
        }
    }
}

// MARK: - Bottom Action Bar
struct BottomActionBar: View {
    @ObservedObject var sender: BestSender
    @Binding var showingModeSelector: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            // Mode Info
            HStack(spacing: 8) {
                Image(systemName: "square.grid.3x3")
                    .font(.system(size: 16))
                    .foregroundColor(.cyan)
                Text("UNIFIED DASHBOARD")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            
            Spacer()
            
            // Status Info
            Text("DEVICES: \(sender.discoveredDevices.filter { $0.isConnected }.count) | LATENCY: \(String(format: "%.1f", sender.averageLatency))ms | QUALITY: \(sender.networkHealth)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)
            
            Spacer()
            
            // Quick Actions
            HStack(spacing: 10) {
                Button("SETTINGS") {
                    showingModeSelector = true
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.6))
                .cornerRadius(6)
                .buttonStyle(PlainButtonStyle())
                
                Button("MINIMAL") {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        sender.uiMode = .minimal
                    }
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.6))
                .cornerRadius(6)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.8))
        .border(Color.gray.opacity(0.3), width: 1)
    }
}

// MARK: - Mode Selector
struct ModeSelector: View {
    @ObservedObject var sender: BestSender
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Interface Settings")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            // UI Mode Selection
            VStack(spacing: 15) {
                Text("UI Mode")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                Picker("UI Mode", selection: $sender.uiMode) {
                    ForEach(UIMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 300)
            }
            
            // Color Scheme Selection
            VStack(spacing: 15) {
                Text("Theme")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                Picker("Theme", selection: $sender.colorScheme) {
                    ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.displayName).tag(scheme)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 250)
            }
            
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 10)
            .background(Color.blue)
            .cornerRadius(8)
            .buttonStyle(PlainButtonStyle())
        }
        .padding(30)
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
        .frame(width: 400, height: 300)
    }
}

#Preview {
    ContentView()
}