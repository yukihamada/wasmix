#!/usr/bin/env swift

// 🎙️ HiAudio Pro Audio Recording Feature
// ストリーミング音声をリアルタイムで高品質録音する機能

import Foundation
import AVFoundation

class HiAudioRecorder: NSObject, ObservableObject {
    
    // MARK: - Properties
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentRecordingFile: URL?
    @Published var recordedFiles: [RecordingFile] = []
    
    private var audioFile: AVAudioFile?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingBuffer: AVAudioPCMBuffer?
    
    // Audio settings
    private let sampleRate: Double = 48000
    private let channels: UInt32 = 2
    private let bitDepth: UInt32 = 24
    
    // File management
    private let recordingsDirectory: URL
    
    // MARK: - Initialization
    
    override init() {
        // Create recordings directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingsDirectory = documentsPath.appendingPathComponent("HiAudio_Recordings")
        
        super.init()
        
        setupRecordingsDirectory()
        loadExistingRecordings()
    }
    
    // MARK: - Public Methods
    
    func startRecording() {
        guard !isRecording else {
            print("⚠️ Recording already in progress")
            return
        }
        
        do {
            try setupNewRecording()
            startRecordingTimer()
            isRecording = true
            recordingStartTime = Date()
            
            print("🎙️ Recording started: \(currentRecordingFile?.lastPathComponent ?? "Unknown")")
            
        } catch {
            print("❌ Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        guard isRecording else {
            print("⚠️ No recording in progress")
            return
        }
        
        finishRecording()
        stopRecordingTimer()
        isRecording = false
        recordingDuration = 0
        
        print("🛑 Recording stopped")
        
        // Add to recorded files list
        if let file = currentRecordingFile {
            let recording = RecordingFile(
                id: UUID(),
                url: file,
                name: file.lastPathComponent,
                duration: Date().timeIntervalSince(recordingStartTime ?? Date()),
                dateCreated: recordingStartTime ?? Date(),
                fileSize: getFileSize(file)
            )
            
            recordedFiles.append(recording)
            print("💾 Recording saved: \(recording.name)")
        }
        
        currentRecordingFile = nil
        recordingStartTime = nil
    }
    
    func writeAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRecording, let file = audioFile else { return }
        
        do {
            try file.write(from: buffer)
        } catch {
            print("❌ Failed to write audio buffer: \(error)")
        }
    }
    
    func deleteRecording(_ recording: RecordingFile) {
        do {
            try FileManager.default.removeItem(at: recording.url)
            recordedFiles.removeAll { $0.id == recording.id }
            print("🗑️ Recording deleted: \(recording.name)")
        } catch {
            print("❌ Failed to delete recording: \(error)")
        }
    }
    
    func exportRecording(_ recording: RecordingFile, to destinationURL: URL) {
        do {
            try FileManager.default.copyItem(at: recording.url, to: destinationURL)
            print("📤 Recording exported to: \(destinationURL.path)")
        } catch {
            print("❌ Failed to export recording: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupRecordingsDirectory() {
        do {
            try FileManager.default.createDirectory(at: recordingsDirectory, 
                                                  withIntermediateDirectories: true, 
                                                  attributes: nil)
        } catch {
            print("❌ Failed to create recordings directory: \(error)")
        }
    }
    
    private func setupNewRecording() throws {
        let timestamp = DateFormatter.recordingDateFormatter.string(from: Date())
        let filename = "HiAudio_Recording_\(timestamp).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(filename)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
            AVEncoderBitRateKey: 256000 // 256 kbps
        ]
        
        audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
        currentRecordingFile = fileURL
    }
    
    private func finishRecording() {
        audioFile = nil
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let startTime = self.recordingStartTime {
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func loadExistingRecordings() {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: recordingsDirectory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            recordedFiles = files.compactMap { url in
                guard url.pathExtension == "m4a" else { return nil }
                
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                let creationDate = attributes?[.creationDate] as? Date ?? Date()
                let fileSize = attributes?[.size] as? Int64 ?? 0
                
                let duration = getAudioDuration(url)
                
                return RecordingFile(
                    id: UUID(),
                    url: url,
                    name: url.lastPathComponent,
                    duration: duration,
                    dateCreated: creationDate,
                    fileSize: fileSize
                )
            }.sorted { $0.dateCreated > $1.dateCreated }
            
            print("📁 Loaded \(recordedFiles.count) existing recordings")
            
        } catch {
            print("❌ Failed to load existing recordings: \(error)")
        }
    }
    
    private func getFileSize(_ url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func getAudioDuration(_ url: URL) -> TimeInterval {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let sampleRate = audioFile.fileFormat.sampleRate
            let frameCount = audioFile.length
            return Double(frameCount) / sampleRate
        } catch {
            print("⚠️ Failed to get audio duration for \(url.lastPathComponent): \(error)")
            return 0
        }
    }
}

// MARK: - Supporting Types

struct RecordingFile: Identifiable, Codable {
    let id: UUID
    let url: URL
    let name: String
    let duration: TimeInterval
    let dateCreated: Date
    let fileSize: Int64
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedDate: String {
        return DateFormatter.displayDateFormatter.string(from: dateCreated)
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let recordingDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
    
    static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - SwiftUI Integration Example

#if canImport(SwiftUI)
import SwiftUI

struct RecordingControlView: View {
    @ObservedObject var recorder: HiAudioRecorder
    
    var body: some View {
        VStack(spacing: 20) {
            // Recording Status
            HStack {
                Circle()
                    .fill(recorder.isRecording ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
                    .scaleEffect(recorder.isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(), value: recorder.isRecording)
                
                Text(recorder.isRecording ? "RECORDING" : "READY")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(recorder.isRecording ? .red : .gray)
                
                Spacer()
                
                if recorder.isRecording {
                    Text(formatTime(recorder.recordingDuration))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(.cyan)
                }
            }
            
            // Control Buttons
            HStack(spacing: 20) {
                Button(action: {
                    if recorder.isRecording {
                        recorder.stopRecording()
                    } else {
                        recorder.startRecording()
                    }
                }) {
                    HStack {
                        Image(systemName: recorder.isRecording ? "stop.fill" : "record.circle")
                            .font(.title)
                        Text(recorder.isRecording ? "Stop" : "Record")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(recorder.isRecording ? Color.red : Color.green)
                    .cornerRadius(10)
                }
                
                if !recorder.recordedFiles.isEmpty {
                    NavigationLink("Recordings (\(recorder.recordedFiles.count))") {
                        RecordingListView(recorder: recorder)
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(15)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval / 3600)
        let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct RecordingListView: View {
    @ObservedObject var recorder: HiAudioRecorder
    
    var body: some View {
        List {
            ForEach(recorder.recordedFiles) { recording in
                RecordingRowView(recording: recording, recorder: recorder)
            }
        }
        .navigationTitle("Recordings")
    }
}

struct RecordingRowView: View {
    let recording: RecordingFile
    @ObservedObject var recorder: HiAudioRecorder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(recording.name)
                    .font(.headline)
                Spacer()
                Text(recording.formattedDuration)
                    .font(.caption)
                    .padding(4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
            
            HStack {
                Text(recording.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(recording.formattedFileSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("Export") {
                    // Export functionality
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(4)
                
                Button("Delete") {
                    recorder.deleteRecording(recording)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}
#endif

// MARK: - Usage Example

print("🎙️ HiAudio Pro Recording Feature Initialized")

let recorder = HiAudioRecorder()

// Example usage:
print("📁 Available recordings: \(recorder.recordedFiles.count)")

// The recorder is now ready to be integrated with the main audio system
// In your audio processing loop, call: recorder.writeAudioBuffer(audioBuffer)