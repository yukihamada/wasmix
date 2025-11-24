# Implementation Plan

## Goal
Create a high-performance, ultra-low latency audio streaming system between macOS (sender) and iOS (receiver) devices using UDP unicast with 2x redundant transmission for maximum reliability and minimal latency.

## Scope
- **Include**: macOS microphone capture, iOS audio playback, UDP networking, packet deduplication, professional audio quality (48kHz/Float32)
- **Exclude**: Audio compression, GUI beyond basic controls, multi-user support, network discovery

## Acceptance Criteria
- [ ] macOS app captures microphone and transmits via UDP (test: speak into mic, verify packets sent)
- [ ] iOS app receives and plays audio with <10ms latency (test: clap test between devices)
- [ ] Packet loss handling via 2x transmission (test: simulate network issues)
- [ ] No audio dropouts under normal Wi-Fi conditions (test: 5-minute continuous streaming)
- [ ] Professional audio quality: 48kHz sample rate, Float32 PCM format

## Steps (7 small steps)
1) **Project Setup**: Create Xcode projects for macOS and iOS with proper entitlements
2) **Shared Protocol**: Implement AudioPacket serialization/deserialization
3) **macOS Sender Core**: Basic audio capture and UDP transmission
4) **iOS Receiver Core**: Basic UDP reception and audio playback
5) **Redundancy Implementation**: Add 2x transmission with 1ms delay
6) **Deduplication Logic**: Implement packet ID tracking on receiver
7) **Performance Optimization**: Fine-tune buffer sizes and QoS settings

## Rollback Plan
- Keep each step in separate commits
- Test core functionality before adding redundancy
- Fall back to larger buffer sizes if audio glitches occur

## Risks & Open Questions
- **High Priority**: iOS background execution limitations - may need foreground mode
- **Medium Priority**: Network configuration complexity - requires manual IP setup
- **Low Priority**: Buffer underrun on older devices - may need adaptive buffer sizing
- **Open Question**: Optimal redundancy delay (1ms vs 2ms) - needs testing on real networks

## Technical Specifications
- **Audio Format**: 48kHz, 1 channel, Float32 PCM
- **Buffer Size**: 128 frames (2.6ms at 48kHz)
- **Network**: UDP port 55555, QoS voice priority
- **Packet Format**: 8-byte ID + PCM payload
- **Redundancy**: Each packet sent twice, 1ms apart