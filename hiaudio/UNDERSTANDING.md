# Understanding: HiAudio Project

## Current State
This is a new project directory with no existing files. The goal is to create a high-performance, low-latency audio streaming system between macOS and iOS devices using UDP unicast with redundancy transmission.

## Architecture Overview
The system will consist of:
- **macOS Sender Application**: Captures microphone input and transmits audio via UDP
- **iOS Receiver Application**: Receives and plays back audio with minimal latency
- **Shared Protocol**: AudioPacket structure for serialization/deserialization

## Key Technical Requirements
- **Ultra-low latency**: Target 2.6ms buffer sizes (128 frames at 48kHz)
- **High reliability**: UDP unicast with 2x redundant transmission (1ms apart)
- **Professional audio quality**: 48kHz sample rate, Float32 PCM format
- **Network optimization**: QoS voice priority, measurement mode audio session

## Implementation Strategy
The approach uses "brute force reliability" - sending each packet twice with a 1ms delay rather than complex error correction. This maximizes speed while ensuring near-zero packet loss in typical Wi-Fi environments.

## Constraints & Risks
- Requires Wi-Fi network with sufficient bandwidth (2x audio stream)
- Network configuration requires manual IP address setup
- Real-time audio processing demands consistent system performance
- iOS background execution limitations may affect receiver performance

## Dependencies
- AVFoundation for audio capture/playback
- Network framework for UDP communication
- iOS/macOS platform-specific audio session management