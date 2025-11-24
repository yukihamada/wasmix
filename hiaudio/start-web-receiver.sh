#!/bin/bash

# HiAudio Web Receiver Startup Script

echo "🚀 Starting HiAudio Web Receiver..."
echo ""

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed"
    exit 1
fi

# Get local IP address
LOCAL_IP=$(python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    s.connect(('8.8.8.8', 80))
    print(s.getsockname()[0])
finally:
    s.close()
")

echo "🌐 HiAudio Web Receiver"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 iPhone/iPad URL: http://$LOCAL_IP:8082"
echo "💻 Mac Browser:     http://localhost:8082"
echo ""
echo "📋 Instructions:"
echo "   1. Open Safari on your iPhone"
echo "   2. Go to: http://$LOCAL_IP:8082"
echo "   3. Allow microphone access"
echo "   4. Tap 'Add to Home Screen' for app-like experience"
echo "   5. Tap CONNECT to start receiving audio"
echo ""
echo "🔥 Starting web server on port 8082..."
echo "   Press Ctrl+C to stop"
echo ""

# Start the Python web server
cd "$(dirname "$0")"
python3 start-web-server.py