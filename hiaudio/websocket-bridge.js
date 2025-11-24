#!/usr/bin/env node

/**
 * HiAudio WebSocket Bridge
 * Bridges UDP audio packets from Mac to WebSocket for web clients
 */

const WebSocket = require('ws');
const dgram = require('dgram');
const http = require('http');
const path = require('path');
const fs = require('fs');

class HiAudioWebSocketBridge {
    constructor() {
        this.udpPort = 55555;
        this.wsPort = 8081;
        this.httpPort = 8080;
        this.clients = new Set();
        this.stats = {
            packetsReceived: 0,
            clientsConnected: 0,
            bytesTransferred: 0
        };
        
        this.setupUDPListener();
        this.setupWebSocketServer();
        this.setupHTTPServer();
    }
    
    setupUDPListener() {
        this.udpServer = dgram.createSocket('udp4');
        
        this.udpServer.on('message', (msg, rinfo) => {
            this.stats.packetsReceived++;
            this.stats.bytesTransferred += msg.length;
            
            if (this.stats.packetsReceived % 75 === 0) {
                console.log(`📦 Packets: ${this.stats.packetsReceived}, Clients: ${this.clients.size}, From: ${rinfo.address}:${rinfo.port}`);
            }
            
            // Broadcast to all connected web clients
            this.broadcastToClients({
                type: 'audio-packet',
                data: msg.toString('base64'),
                timestamp: Date.now(),
                source: rinfo.address
            });
        });
        
        this.udpServer.on('listening', () => {
            const address = this.udpServer.address();
            console.log(`🎵 UDP Audio Listener: ${address.address}:${address.port}`);
        });
        
        this.udpServer.on('error', (err) => {
            console.error(`❌ UDP Error: ${err}`);
        });
        
        this.udpServer.bind(this.udpPort);
    }
    
    setupWebSocketServer() {
        this.wss = new WebSocket.Server({ port: this.wsPort });
        
        this.wss.on('connection', (ws, req) => {
            const clientIP = req.socket.remoteAddress;
            console.log(`📱 Web client connected: ${clientIP}`);
            
            this.clients.add(ws);
            this.stats.clientsConnected = this.clients.size;
            
            // Send current stats to new client
            ws.send(JSON.stringify({
                type: 'connection-status',
                status: 'connected',
                stats: this.stats
            }));
            
            ws.on('message', (message) => {
                try {
                    const data = JSON.parse(message);
                    this.handleClientMessage(ws, data);
                } catch (err) {
                    console.error('Invalid message from client:', err);
                }
            });
            
            ws.on('close', () => {
                console.log(`📱 Web client disconnected: ${clientIP}`);
                this.clients.delete(ws);
                this.stats.clientsConnected = this.clients.size;
            });
            
            ws.on('error', (err) => {
                console.error(`WebSocket error: ${err}`);
                this.clients.delete(ws);
            });
        });
        
        console.log(`🔌 WebSocket Server: ws://localhost:${this.wsPort}`);
    }
    
    setupHTTPServer() {
        const server = http.createServer((req, res) => {
            let filePath = path.join(__dirname, req.url === '/' ? 'web-receiver.html' : req.url);
            
            // Security check
            if (!filePath.startsWith(__dirname)) {
                res.writeHead(403);
                res.end('Forbidden');
                return;
            }
            
            // Serve files
            fs.readFile(filePath, (err, data) => {
                if (err) {
                    res.writeHead(404);
                    res.end('File not found');
                    return;
                }
                
                // Set content type
                const ext = path.extname(filePath);
                const contentType = {
                    '.html': 'text/html',
                    '.js': 'application/javascript',
                    '.css': 'text/css',
                    '.json': 'application/json'
                }[ext] || 'text/plain';
                
                res.writeHead(200, {
                    'Content-Type': contentType,
                    'Access-Control-Allow-Origin': '*'
                });
                res.end(data);
            });
        });
        
        server.listen(this.httpPort, () => {
            const localIP = this.getLocalIP();
            console.log(`🌐 HTTP Server: http://${localIP}:${this.httpPort}`);
            console.log(`📱 iPhone URL: http://${localIP}:${this.httpPort}`);
        });
    }
    
    handleClientMessage(ws, data) {
        switch (data.type) {
            case 'ping':
                ws.send(JSON.stringify({
                    type: 'pong',
                    timestamp: Date.now()
                }));
                break;
                
            case 'request-stats':
                ws.send(JSON.stringify({
                    type: 'stats-update',
                    stats: this.stats
                }));
                break;
                
            default:
                console.log('Unknown message type:', data.type);
        }
    }
    
    broadcastToClients(message) {
        const messageStr = JSON.stringify(message);
        
        this.clients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                try {
                    client.send(messageStr);
                } catch (err) {
                    console.error('Error sending to client:', err);
                    this.clients.delete(client);
                }
            } else {
                this.clients.delete(client);
            }
        });
    }
    
    getLocalIP() {
        const { networkInterfaces } = require('os');
        const nets = networkInterfaces();
        
        for (const name of Object.keys(nets)) {
            for (const net of nets[name]) {
                if (net.family === 'IPv4' && !net.internal) {
                    return net.address;
                }
            }
        }
        return 'localhost';
    }
    
    startStatsReporting() {
        setInterval(() => {
            this.broadcastToClients({
                type: 'stats-update',
                stats: this.stats,
                timestamp: Date.now()
            });
        }, 1000);
    }
}

// Start the bridge
console.log('🚀 Starting HiAudio WebSocket Bridge...');
const bridge = new HiAudioWebSocketBridge();
bridge.startStatsReporting();

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down HiAudio Bridge...');
    process.exit(0);
});

process.on('uncaughtException', (err) => {
    console.error('💥 Uncaught Exception:', err);
    process.exit(1);
});