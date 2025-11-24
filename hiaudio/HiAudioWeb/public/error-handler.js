// 🚨 HiAudio Pro Web - Enhanced Error Handler
class HiAudioErrorHandler {
    constructor() {
        this.errors = [];
        this.maxErrors = 50;
        this.setupGlobalErrorHandlers();
    }
    
    setupGlobalErrorHandlers() {
        // Web Audio API エラー
        window.addEventListener('unhandledrejection', (event) => {
            if (event.reason && event.reason.name === 'NotAllowedError') {
                this.handleAutoplayError();
            }
        });
        
        // WebSocket接続エラー
        window.addEventListener('error', (event) => {
            if (event.message.includes('WebSocket')) {
                this.handleWebSocketError(event);
            }
        });
    }
    
    handleAutoplayError() {
        const notification = document.createElement('div');
        notification.className = 'error-notification';
        notification.innerHTML = `
            <div class="error-content">
                <h3>🔊 音声再生の許可が必要です</h3>
                <p>ブラウザのセキュリティ設定により、音声の自動再生がブロックされています。</p>
                <button onclick="this.parentElement.parentElement.remove()">
                    ブラウザ設定で音声を許可してください
                </button>
            </div>
        `;
        
        document.body.appendChild(notification);
        
        // 10秒後に自動削除
        setTimeout(() => {
            if (notification.parentNode) {
                notification.remove();
            }
        }, 10000);
    }
    
    handleWebSocketError(event) {
        console.error('WebSocket Error:', event);
        
        // 接続状態表示を更新
        const statusElement = document.getElementById('connectionStatus');
        if (statusElement) {
            statusElement.className = 'connection-status disconnected';
            statusElement.textContent = '接続エラー - 再接続中...';
        }
        
        // 自動再接続を試行
        setTimeout(() => {
            if (window.hiAudioClient && window.hiAudioClient.socket) {
                window.hiAudioClient.socket.connect();
            }
        }, 3000);
    }
    
    handleUDPPacketLoss(lostPackets) {
        const lossRate = (lostPackets / 1000) * 100; // 過去1000パケット中の損失率
        
        if (lossRate > 1.0) { // 1%以上の損失
            this.showNetworkWarning(lossRate);
        }
    }
    
    showNetworkWarning(lossRate) {
        const warning = document.getElementById('networkWarning') || 
                       this.createNetworkWarning();
        
        warning.innerHTML = `
            <div class="warning-content">
                <span class="warning-icon">⚠️</span>
                <span>ネットワーク品質低下: ${lossRate.toFixed(1)}% packet loss</span>
                <button onclick="this.showNetworkTips()">改善方法</button>
            </div>
        `;
        warning.style.display = 'block';
    }
    
    createNetworkWarning() {
        const warning = document.createElement('div');
        warning.id = 'networkWarning';
        warning.className = 'network-warning';
        warning.style.cssText = `
            position: fixed;
            top: 60px;
            right: 20px;
            background: linear-gradient(135deg, #ff9500, #ff6b00);
            color: white;
            padding: 15px;
            border-radius: 10px;
            box-shadow: 0 5px 15px rgba(255, 149, 0, 0.3);
            z-index: 1001;
            display: none;
        `;
        document.body.appendChild(warning);
        return warning;
    }
    
    showNetworkTips() {
        const tips = document.createElement('div');
        tips.className = 'network-tips-modal';
        tips.innerHTML = `
            <div class="modal-overlay" onclick="this.parentElement.remove()">
                <div class="modal-content" onclick="event.stopPropagation()">
                    <h3>🌐 ネットワーク品質改善方法</h3>
                    <ul>
                        <li><strong>有線LANに変更</strong> - Wi-Fiより安定</li>
                        <li><strong>5GHz Wi-Fi使用</strong> - 2.4GHzより高速</li>
                        <li><strong>他のアプリを終了</strong> - 帯域を確保</li>
                        <li><strong>ルーター近くに移動</strong> - 電波強度向上</li>
                        <li><strong>QoS設定</strong> - ルーターでHiAudio優先</li>
                    </ul>
                    <button onclick="this.parentElement.parentElement.remove()">
                        OK
                    </button>
                </div>
            </div>
        `;
        
        tips.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.7);
            z-index: 2000;
            display: flex;
            align-items: center;
            justify-content: center;
        `;
        
        document.body.appendChild(tips);
    }
    
    // パフォーマンス監視
    monitorPerformance() {
        const observer = new PerformanceObserver((list) => {
            const entries = list.getEntries();
            entries.forEach((entry) => {
                if (entry.duration > 16.67) { // 60fps = 16.67ms
                    console.warn(`Performance Warning: ${entry.name} took ${entry.duration}ms`);
                }
            });
        });
        
        observer.observe({ entryTypes: ['measure', 'navigation'] });
    }
    
    // システム診断
    async runDiagnostics() {
        const results = {
            webAudio: await this.testWebAudioSupport(),
            webSocket: await this.testWebSocketConnection(),
            performance: await this.testPerformance(),
            network: await this.testNetworkSpeed()
        };
        
        console.table(results);
        return results;
    }
    
    async testWebAudioSupport() {
        try {
            const context = new (window.AudioContext || window.webkitAudioContext)();
            await context.resume();
            context.close();
            return { status: 'OK', latency: context.baseLatency * 1000 };
        } catch (error) {
            return { status: 'ERROR', error: error.message };
        }
    }
    
    async testWebSocketConnection() {
        return new Promise((resolve) => {
            const socket = new WebSocket(`ws://${location.host}`);
            const timeout = setTimeout(() => {
                socket.close();
                resolve({ status: 'TIMEOUT' });
            }, 5000);
            
            socket.onopen = () => {
                clearTimeout(timeout);
                socket.close();
                resolve({ status: 'OK' });
            };
            
            socket.onerror = (error) => {
                clearTimeout(timeout);
                resolve({ status: 'ERROR', error: error.message });
            };
        });
    }
    
    async testPerformance() {
        const start = performance.now();
        
        // CPU集約的なタスクを実行
        const testArray = new Float32Array(44100);
        for (let i = 0; i < testArray.length; i++) {
            testArray[i] = Math.sin(i * 0.1);
        }
        
        const duration = performance.now() - start;
        
        return {
            status: duration < 10 ? 'GOOD' : duration < 50 ? 'OK' : 'POOR',
            processingTime: duration
        };
    }
    
    async testNetworkSpeed() {
        const start = performance.now();
        try {
            await fetch('/api/stats');
            const duration = performance.now() - start;
            
            return {
                status: duration < 50 ? 'GOOD' : duration < 200 ? 'OK' : 'POOR',
                latency: duration
            };
        } catch (error) {
            return { status: 'ERROR', error: error.message };
        }
    }
}

// グローバルエラーハンドラーを初期化
window.hiAudioErrorHandler = new HiAudioErrorHandler();

// 診断ボタンを追加
document.addEventListener('DOMContentLoaded', () => {
    const diagnosticsButton = document.createElement('button');
    diagnosticsButton.textContent = '🔍 診断実行';
    diagnosticsButton.style.cssText = `
        position: fixed;
        bottom: 20px;
        left: 20px;
        background: #007bff;
        color: white;
        border: none;
        padding: 10px 15px;
        border-radius: 8px;
        cursor: pointer;
        z-index: 1000;
        font-size: 12px;
    `;
    
    diagnosticsButton.onclick = async () => {
        const results = await window.hiAudioErrorHandler.runDiagnostics();
        
        // 結果をモーダルで表示
        const modal = document.createElement('div');
        modal.innerHTML = `
            <div class="modal-overlay" onclick="this.parentElement.remove()">
                <div class="modal-content" onclick="event.stopPropagation()">
                    <h3>🔍 システム診断結果</h3>
                    <pre>${JSON.stringify(results, null, 2)}</pre>
                    <button onclick="this.parentElement.parentElement.remove()">
                        閉じる
                    </button>
                </div>
            </div>
        `;
        document.body.appendChild(modal);
    };
    
    document.body.appendChild(diagnosticsButton);
});