#!/usr/bin/env python3
import http.server
import socketserver
import webbrowser
import socket
import os
import sys

def get_local_ip():
    """Get the local IP address"""
    try:
        # Connect to a remote address (doesn't actually connect)
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "localhost"

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Add CORS headers for cross-origin requests
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

    def do_GET(self):
        if self.path == '/' or self.path == '/index.html':
            self.path = '/web-receiver.html'
        return super().do_GET()

def main():
    PORT = 8082
    
    # Change to the directory containing web-receiver.html
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    
    if not os.path.exists('web-receiver.html'):
        print("❌ Error: web-receiver.html not found in current directory")
        sys.exit(1)
    
    local_ip = get_local_ip()
    
    with socketserver.TCPServer(("", PORT), MyHTTPRequestHandler) as httpd:
        print(f"🌐 HiAudio Web Server Started!")
        print(f"📱 iPhone/iPad: http://{local_ip}:{PORT}")
        print(f"💻 Mac/PC: http://localhost:{PORT}")
        print(f"🔗 Direct: http://127.0.0.1:{PORT}")
        print(f"\n🔥 Server running on port {PORT}")
        print("   Press Ctrl+C to stop")
        print("   📲 Access from iPhone Safari for best experience!")
        
        try:
            # Auto-open browser on Mac
            webbrowser.open(f"http://localhost:{PORT}")
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n🛑 Server stopped")

if __name__ == "__main__":
    main()