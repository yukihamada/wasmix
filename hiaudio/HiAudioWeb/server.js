#!/usr/bin/env node

const express = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const QRCode = require('qrcode');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const os = require('os');

// 🎵 **HiAudio Pro Web Server** - Ultra-low latency audio streaming
const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    },
    pingInterval: 25000,
    pingTimeout: 60000,
    upgradeTimeout: 30000,
    maxHttpBufferSize: 1e8, // 100MB for large audio buffers
    transports: ['websocket', 'polling']
});

// Configuration
const PORT = process.env.PORT || 3000;
const AUDIO_PORT = process.env.AUDIO_PORT || 55556; // Same as UDP port for consistency

// Server state
let connectedClients = new Map();
let audioSessions = new Map();
let serverStats = {
    startTime: Date.now(),
    totalConnections: 0,
    activeConnections: 0,
    audioPacketsReceived: 0,
    totalDataReceived: 0
};

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.static(path.join(__dirname, 'public')));

// Get local IP address
function getLocalIPAddress() {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const interface of interfaces[name]) {
            if (interface.family === 'IPv4' && !interface.internal) {
                return interface.address;
            }
        }
    }
    return 'localhost';
}

// Generate connection URL and QR code
async function generateConnectionInfo() {
    const localIP = getLocalIPAddress();
    const webUrl = `http://${localIP}:${PORT}`;
    const connectionInfo = {
        webUrl,
        audioPort: AUDIO_PORT,
        serverIP: localIP,
        timestamp: Date.now()
    };
    
    try {
        const qrCode = await QRCode.toDataURL(JSON.stringify(connectionInfo));
        return { ...connectionInfo, qrCode };
    } catch (error) {
        console.error('❌ QR Code generation failed:', error);
        return connectionInfo;
    }
}

// 🌐 **Web Routes**
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// API endpoint for connection info
app.get('/api/connection-info', async (req, res) => {
    try {
        const info = await generateConnectionInfo();
        res.json(info);
    } catch (error) {
        console.error('❌ Connection info generation failed:', error);
        res.status(500).json({ error: 'Failed to generate connection info' });
    }
});

// API endpoint for server stats
app.get('/api/stats', (req, res) => {
    const uptime = Date.now() - serverStats.startTime;
    res.json({
        ...serverStats,
        uptime,
        localIP: getLocalIPAddress(),
        port: PORT,
        audioPort: AUDIO_PORT
    });
});

// 🔊 **WebSocket Audio Streaming**
io.on('connection', (socket) => {
    console.log(`🌐 New client connected: ${socket.id}`);
    
    const clientId = uuidv4();
    const clientInfo = {
        id: clientId,
        socketId: socket.id,
        connectedAt: Date.now(),
        isReceivingAudio: false,
        packetsReceived: 0,
        lastPingTime: Date.now(),
        latency: 0,
        userAgent: socket.handshake.headers['user-agent'] || 'Unknown'
    };
    
    connectedClients.set(socket.id, clientInfo);
    serverStats.totalConnections++;
    serverStats.activeConnections++;
    
    // Send welcome message with client ID
    socket.emit('connected', {
        clientId,
        serverTime: Date.now(),
        audioFormat: {
            sampleRate: 96000,
            channels: 2,
            bitDepth: 32,
            encoding: 'float32'
        }
    });
    
    // Handle audio stream start
    socket.on('start-audio', (data) => {
        console.log(`🎵 Client ${socket.id} started audio reception`);
        const client = connectedClients.get(socket.id);
        if (client) {
            client.isReceivingAudio = true;
            client.audioStartTime = Date.now();
        }
        
        socket.emit('audio-started', { 
            status: 'ready',
            timestamp: Date.now() 
        });
    });
    
    // Handle audio stream stop
    socket.on('stop-audio', () => {
        console.log(`🔇 Client ${socket.id} stopped audio reception`);
        const client = connectedClients.get(socket.id);
        if (client) {
            client.isReceivingAudio = false;
        }
        
        socket.emit('audio-stopped', { 
            timestamp: Date.now() 
        });
    });
    
    // Handle ping for latency measurement
    socket.on('ping', (data) => {
        const client = connectedClients.get(socket.id);
        if (client) {
            client.lastPingTime = Date.now();
            client.latency = data.latency || 0;
        }
        
        socket.emit('pong', {
            timestamp: Date.now(),
            originalTimestamp: data.timestamp
        });
    });
    
    // Handle audio data from macOS sender (if sent via WebSocket)
    socket.on('audio-data', (audioData) => {
        const client = connectedClients.get(socket.id);
        if (client && client.isReceivingAudio) {
            client.packetsReceived++;
            serverStats.audioPacketsReceived++;
            serverStats.totalDataReceived += audioData.length || 0;
            
            // Broadcast audio to other clients if needed
            socket.broadcast.emit('audio-stream', audioData);
        }
    });
    
    // Handle client settings updates
    socket.on('update-settings', (settings) => {
        console.log(`⚙️ Client ${socket.id} updated settings:`, settings);
        const client = connectedClients.get(socket.id);
        if (client) {
            client.settings = { ...client.settings, ...settings };
        }
    });
    
    // Handle disconnect
    socket.on('disconnect', (reason) => {
        console.log(`👋 Client disconnected: ${socket.id} (${reason})`);
        connectedClients.delete(socket.id);
        serverStats.activeConnections = Math.max(0, serverStats.activeConnections - 1);
    });
    
    // Send periodic stats updates
    const statsInterval = setInterval(() => {
        const client = connectedClients.get(socket.id);
        if (!client) {
            clearInterval(statsInterval);
            return;
        }
        
        socket.emit('stats-update', {
            packetsReceived: client.packetsReceived,
            latency: client.latency,
            isReceivingAudio: client.isReceivingAudio,
            uptime: Date.now() - client.connectedAt
        });
    }, 1000);
});

// 📊 **UDP Audio Receiver** (for direct macOS connection)
const dgram = require('dgram');
const udpServer = dgram.createSocket('udp4');

udpServer.on('message', (msg, rinfo) => {
    try {
        // Parse audio packet (assuming same format as iOS/macOS)
        const audioPacket = parseAudioPacket(msg);
        if (!audioPacket) return;
        
        serverStats.audioPacketsReceived++;
        serverStats.totalDataReceived += msg.length;
        
        // Convert binary audio data to format suitable for web audio
        const audioData = {
            id: audioPacket.id,
            timestamp: audioPacket.timestamp,
            sampleRate: 96000,
            channels: 2,
            data: Array.from(new Float32Array(audioPacket.payload.buffer))
        };
        
        // Broadcast to all connected web clients
        io.emit('audio-stream', audioData);
        
        // Log every second (750 packets/sec at 96kHz)
        if (audioPacket.id % 750 === 0) {
            console.log(`📡 UDP Audio: Packet ${audioPacket.id} from ${rinfo.address}, ${connectedClients.size} web clients`);
        }
        
    } catch (error) {
        console.error('❌ UDP packet processing error:', error);
    }
});

udpServer.on('listening', () => {
    const address = udpServer.address();
    console.log(`🎵 UDP Audio Server listening on ${address.address}:${address.port}`);
});

udpServer.bind(AUDIO_PORT);

// Parse audio packet (simplified version of the Swift AudioPacket)
function parseAudioPacket(buffer) {
    try {
        if (buffer.length < 16) return null; // Minimum packet size
        
        // Read packet header (assuming same format as Swift)
        const id = buffer.readBigUInt64BE(0);
        const timestamp = buffer.readDoubleLE(8);
        const payload = buffer.slice(16);
        
        return {
            id: Number(id),
            timestamp,
            payload: payload
        };
    } catch (error) {
        console.error('❌ Packet parsing error:', error);
        return null;
    }
}

// 🔒 **HTTPS Support** (optional)
const https = require('https');
const fs = require('fs');

let server = httpServer;

// HTTPS証明書がある場合は自動的にHTTPS使用
const httpsOptions = {
    key: process.env.SSL_KEY || './ssl/server.key',
    cert: process.env.SSL_CERT || './ssl/server.crt'
};

if (fs.existsSync(httpsOptions.key) && fs.existsSync(httpsOptions.cert)) {
    try {
        const httpsServer = https.createServer({
            key: fs.readFileSync(httpsOptions.key),
            cert: fs.readFileSync(httpsOptions.cert)
        }, app);
        
        // Socket.ioをHTTPSサーバーに再接続
        const httpsIO = new Server(httpsServer, {
            cors: { origin: "*", methods: ["GET", "POST"] }
        });
        
        // HTTPSサーバー用の同じロジックを適用
        httpsIO.on('connection', (socket) => {
            // 既存のSocket.ioロジックをコピー
            console.log(`🔒 HTTPS client connected: ${socket.id}`);
            // ... (同じイベントハンドラーを適用)
        });
        
        server = httpsServer;
        console.log('🔒 HTTPS certificates found - using secure connection');
        
    } catch (error) {
        console.warn('⚠️ HTTPS setup failed, falling back to HTTP:', error.message);
    }
}

// 🚀 **Start Server**
server.listen(PORT, '0.0.0.0', async () => {
    const protocol = server instanceof https.Server ? 'https' : 'http';
    const securityStatus = protocol === 'https' ? '🔒 SECURE' : '⚠️ HTTP ONLY';
    
    console.log('\n🎵 ==========================================');
    console.log('   HiAudio Pro Web Server Started');
    console.log('🎵 ==========================================');
    console.log(`🌐 Web Interface: ${protocol}://localhost:${PORT}`);
    console.log(`📡 UDP Audio Port: ${AUDIO_PORT}`);
    console.log(`🖥️  Local IP: ${getLocalIPAddress()}`);
    console.log(`${securityStatus}`);
    
    if (protocol === 'http') {
        console.log('');
        console.log('📋 HTTPS化手順 (推奨):');
        console.log('   1. mkdir ssl');
        console.log('   2. openssl req -x509 -newkey rsa:4096 -keyout ssl/server.key -out ssl/server.crt -days 365 -nodes');
        console.log('   3. サーバー再起動で自動的にHTTPS有効');
    }
    
    console.log('🎵 ==========================================\n');
    
    // Generate and display QR code info
    try {
        const connectionInfo = await generateConnectionInfo();
        connectionInfo.protocol = protocol;
        console.log(`📱 Connection URL: ${connectionInfo.webUrl}`);
        console.log('🔗 Audio Port:', connectionInfo.audioPort);
        console.log('📱 Share this URL or scan QR code from macOS app\n');
        
        // セキュリティ警告
        if (protocol === 'http') {
            console.log('⚠️  WARNING: HTTP mode - some browsers may block audio features');
            console.log('   Consider using HTTPS for full functionality\n');
        }
        
    } catch (error) {
        console.error('❌ Connection info generation failed:', error);
    }
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('\n👋 Shutting down HiAudio Web Server...');
    httpServer.close(() => {
        udpServer.close();
        console.log('✅ Server shut down gracefully');
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    console.log('\n👋 Shutting down HiAudio Web Server...');
    httpServer.close(() => {
        udpServer.close();
        console.log('✅ Server shut down gracefully');
        process.exit(0);
    });
});