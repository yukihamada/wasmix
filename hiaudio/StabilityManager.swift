#!/usr/bin/env swift

// 🔧 HiAudio Pro Stability Manager - システム安定化統合管理

import Foundation
import Network
import os.log

class HiAudioStabilityManager {
    
    // MARK: - Singleton Instance
    static let shared = HiAudioStabilityManager()
    
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.hiaudio.stability", category: "manager")
    private var isMonitoring = false
    private var processMonitorTimer: Timer?
    private var networkMonitorTimer: Timer?
    private var memoryMonitorTimer: Timer?
    
    // Stats tracking
    private var startTime = Date()
    private var totalConnections = 0
    private var successfulConnections = 0
    private var networkErrors = 0
    private var memoryWarnings = 0
    
    private init() {
        setupCrashHandling()
        setupMemoryWarning()
    }
    
    // MARK: - Public Methods
    
    func startStabilityMonitoring() {
        guard !isMonitoring else {
            logger.info("🔧 Stability monitoring already running")
            return
        }
        
        isMonitoring = true
        logger.info("🚀 Starting HiAudio Stability Manager")
        
        // Kill duplicate processes first
        cleanupDuplicateProcesses()
        
        // Start monitoring systems
        startProcessMonitoring()
        startNetworkMonitoring()
        startMemoryMonitoring()
        
        // Setup auto-recovery
        setupAutoRecovery()
        
        logger.info("✅ Stability monitoring active")
        printSystemStatus()
    }
    
    func stopStabilityMonitoring() {
        isMonitoring = false
        
        processMonitorTimer?.invalidate()
        networkMonitorTimer?.invalidate()
        memoryMonitorTimer?.invalidate()
        
        logger.info("🛑 Stability monitoring stopped")
        printFinalReport()
    }
    
    // MARK: - Process Management
    
    private func cleanupDuplicateProcesses() {
        logger.info("🧹 Cleaning up duplicate HiAudio processes...")
        
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["-9", "HiAudioSender"]
        
        do {
            try task.run()
            task.waitUntilExit()
            Thread.sleep(forTimeInterval: 1.0)
            logger.info("✅ Duplicate processes cleaned up")
        } catch {
            logger.error("❌ Failed to cleanup processes: \\(error)")
        }
    }
    
    private func startProcessMonitoring() {
        processMonitorTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.checkProcessHealth()
        }
    }
    
    private func checkProcessHealth() {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["aux"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let hiAudioProcesses = output.components(separatedBy: "\\n")
                .filter { $0.contains("HiAudio") || $0.contains("node server.js") }
                .count
            
            if hiAudioProcesses > 3 {
                logger.warning("⚠️ Too many HiAudio processes running: \\(hiAudioProcesses)")
                cleanupDuplicateProcesses()
            }
            
        } catch {
            logger.error("❌ Process monitoring error: \\(error)")
        }
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        networkMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.checkNetworkHealth()
        }
    }
    
    private func checkNetworkHealth() {
        // Check web server port 3000
        checkPortHealth("localhost", port: 3000, service: "Web Server")
        
        // Check audio port 55556
        checkPortHealth("localhost", port: 55556, service: "Audio UDP")
        
        // Check network connectivity
        testNetworkConnectivity()
    }
    
    private func checkPortHealth(_ host: String, port: Int, service: String) {
        let semaphore = DispatchSemaphore(value: 0)
        var isHealthy = false
        
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: UInt16(port))!,
            using: .tcp
        )
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                isHealthy = true
                semaphore.signal()
            case .failed(_):
                isHealthy = false
                semaphore.signal()
            default:
                break
            }
        }
        
        connection.start(queue: .global())
        
        DispatchQueue.global().async {
            _ = semaphore.wait(timeout: .now() + 2.0)
            connection.cancel()
            
            if isHealthy {
                self.successfulConnections += 1
                self.logger.debug("✅ \\(service) (port \\(port)) is healthy")
            } else {
                self.networkErrors += 1
                self.logger.warning("❌ \\(service) (port \\(port)) is not responding")
                
                // Auto-restart if needed
                if service == "Web Server" {
                    self.restartWebServer()
                }
            }
            
            self.totalConnections += 1
        }
    }
    
    private func testNetworkConnectivity() {
        // Test external connectivity
        guard let url = URL(string: "http://www.google.com") else { return }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if error != nil {
                self.logger.warning("⚠️ External network connectivity issues")
            }
        }
        task.resume()
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring() {
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
            self.checkMemoryUsage()
        }
    }
    
    private func checkMemoryUsage() {
        let task = Process()
        task.launchPath = "/usr/bin/top"
        task.arguments = ["-l", "1", "-o", "mem", "-n", "5"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Extract memory info
            let memoryLines = output.components(separatedBy: "\\n")
                .filter { $0.contains("PhysMem") }
            
            if let memLine = memoryLines.first {
                logger.debug("💾 Memory status: \\(memLine)")
                
                // Check for memory pressure
                if memLine.contains("pressure") {
                    memoryWarnings += 1
                    logger.warning("⚠️ Memory pressure detected")
                    triggerMemoryCleanup()
                }
            }
            
        } catch {
            logger.error("❌ Memory monitoring error: \\(error)")
        }
    }
    
    // MARK: - Auto Recovery
    
    private func setupAutoRecovery() {
        // Monitor system for automatic recovery
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.performHealthCheck()
        }
    }
    
    private func performHealthCheck() {
        let healthScore = calculateHealthScore()
        
        if healthScore < 0.5 {
            logger.warning("🚨 System health critical (\\(String(format: \"%.1f\", healthScore * 100))%), triggering recovery")
            triggerSystemRecovery()
        } else if healthScore < 0.8 {
            logger.info("⚠️ System health degraded (\\(String(format: \"%.1f\", healthScore * 100))%)")
        } else {
            logger.debug("✅ System health good (\\(String(format: \"%.1f\", healthScore * 100))%)")
        }
    }
    
    private func calculateHealthScore() -> Double {
        let networkHealth = totalConnections > 0 ? Double(successfulConnections) / Double(totalConnections) : 1.0
        let memoryHealth = memoryWarnings < 5 ? 1.0 : 0.5
        let uptimeHealth = min(1.0, Date().timeIntervalSince(startTime) / 3600.0) // Up to 1 hour
        
        return (networkHealth + memoryHealth + uptimeHealth) / 3.0
    }
    
    // MARK: - Recovery Actions
    
    private func restartWebServer() {
        logger.info("🔄 Attempting to restart web server...")
        
        // Kill existing node processes
        let killTask = Process()
        killTask.launchPath = "/usr/bin/killall"
        killTask.arguments = ["node"]
        
        do {
            try killTask.run()
            killTask.waitUntilExit()
            
            Thread.sleep(forTimeInterval: 2.0)
            
            // Restart web server
            let startTask = Process()
            startTask.launchPath = "/usr/bin/nohup"
            startTask.arguments = ["node", "/Users/yuki/hiaudio/HiAudioWeb/server.js"]
            startTask.currentDirectoryPath = "/Users/yuki/hiaudio/HiAudioWeb"
            
            try startTask.run()
            logger.info("✅ Web server restart initiated")
            
        } catch {
            logger.error("❌ Failed to restart web server: \\(error)")
        }
    }
    
    private func triggerMemoryCleanup() {
        logger.info("🧹 Triggering memory cleanup...")
        
        // Force garbage collection (if possible)
        DispatchQueue.global().async {
            autoreleasepool {
                // Perform memory intensive cleanup
                let task = Process()
                task.launchPath = "/usr/bin/purge"
                try? task.run()
                task.waitUntilExit()
            }
        }
    }
    
    private func triggerSystemRecovery() {
        logger.warning("🚨 Initiating system recovery protocol...")
        
        // Step 1: Cleanup processes
        cleanupDuplicateProcesses()
        
        // Step 2: Restart services
        restartWebServer()
        
        // Step 3: Clear memory
        triggerMemoryCleanup()
        
        // Step 4: Reset counters
        networkErrors = 0
        memoryWarnings = 0
        
        logger.info("✅ System recovery completed")
    }
    
    // MARK: - Crash Handling
    
    private func setupCrashHandling() {
        signal(SIGTERM) { _ in
            HiAudioStabilityManager.shared.stopStabilityMonitoring()
            exit(0)
        }
        
        signal(SIGINT) { _ in
            HiAudioStabilityManager.shared.stopStabilityMonitoring()
            exit(0)
        }
    }
    
    private func setupMemoryWarning() {
        // Memory warning notification setup would go here
        // This is simplified for the command line version
    }
    
    // MARK: - Reporting
    
    private func printSystemStatus() {
        print("""
        
        🔧 HiAudio Pro Stability Manager - System Status
        ================================================
        📅 Started: \\(startTime)
        🔄 Monitoring: \\(isMonitoring ? "Active" : "Inactive")
        🌐 Network Health: \\(String(format: "%.1f", totalConnections > 0 ? Double(successfulConnections) / Double(totalConnections) * 100 : 100))%
        💾 Memory Warnings: \\(memoryWarnings)
        ⚠️ Network Errors: \\(networkErrors)
        📊 Health Score: \\(String(format: "%.1f", calculateHealthScore() * 100))%
        ================================================
        """)
    }
    
    private func printFinalReport() {
        let uptime = Date().timeIntervalSince(startTime)
        let hours = Int(uptime / 3600)
        let minutes = Int((uptime.truncatingRemainder(dividingBy: 3600)) / 60)
        
        print("""
        
        📊 HiAudio Pro Stability Report
        ===============================
        ⏱️ Total Uptime: \\(hours)h \\(minutes)m
        🔗 Total Connections: \\(totalConnections)
        ✅ Successful: \\(successfulConnections)
        ❌ Network Errors: \\(networkErrors)
        💾 Memory Warnings: \\(memoryWarnings)
        📈 Final Health Score: \\(String(format: "%.1f", calculateHealthScore() * 100))%
        ===============================
        """)
    }
}

// MARK: - Main Execution

print("🚀 Starting HiAudio Pro Stability Manager...")
print("⚡ Press Ctrl+C to stop")

let stabilityManager = HiAudioStabilityManager.shared
stabilityManager.startStabilityMonitoring()

// Keep the script running
RunLoop.main.run()