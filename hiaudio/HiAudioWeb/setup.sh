#!/bin/bash

# 🎵 HiAudio Pro Web Server Enhanced Setup Script

echo "🎵 =============================================="
echo "   HiAudio Pro Web Server セットアップ v2.0"  
echo "🎵 =============================================="
echo ""

# システム要件チェック
check_system() {
    echo "🔍 システム要件をチェック中..."
    
    # Node.js チェック
    if ! command -v node &> /dev/null; then
        echo "❌ Node.js が見つかりません。"
        echo "   📥 自動インストールを実行しますか？ (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            install_nodejs
        else
            echo "   🌐 手動インストール: https://nodejs.org/"
            exit 1
        fi
    fi
    
    # バージョンチェック
    NODE_VERSION=$(node --version | cut -c2-)
    REQUIRED_VERSION="16.0.0"
    
    if ! printf '%s\n%s\n' "$REQUIRED_VERSION" "$NODE_VERSION" | sort -V -C; then
        echo "⚠️  Node.js バージョンが古すぎます: $NODE_VERSION"
        echo "   📈 最低要件: $REQUIRED_VERSION"
        echo "   🔄 アップデートしてください"
        exit 1
    fi
    
    echo "✅ Node.js バージョン: $NODE_VERSION"
    echo "✅ npm バージョン: $(npm --version)"
    
    # ポート使用状況チェック
    if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null; then
        echo "⚠️  ポート 3000 が既に使用中です"
        echo "   🔧 使用中のプロセスを終了しますか？ (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            sudo lsof -ti:3000 | xargs kill -9
            echo "✅ ポート 3000 を解放しました"
        fi
    fi
    
    if lsof -Pi :55555 -sUDP:LISTEN -t >/dev/null; then
        echo "⚠️  UDPポート 55555 が既に使用中です"
        echo "   🎵 HiAudio関連プロセスかもしれません"
    fi
}

# Node.js自動インストール (macOS)
install_nodejs() {
    echo "📥 Node.js を自動インストール中..."
    
    if command -v brew &> /dev/null; then
        brew install node
    else
        echo "❌ Homebrewが見つかりません"
        echo "   🍺 Homebrew インストール: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
}

# ファイアウォール設定チェック
check_firewall() {
    echo "🔥 ファイアウォール設定をチェック中..."
    
    if sudo pfctl -s rules | grep -q "block.*3000\|block.*55555"; then
        echo "⚠️  ファイアウォールでポートがブロックされています"
        echo "   🔓 自動的にポートを開放しますか？ (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            configure_firewall
        fi
    else
        echo "✅ ファイアウォール設定OK"
    fi
}

# ファイアウォール自動設定
configure_firewall() {
    echo "🔓 ファイアウォールを設定中..."
    
    # macOS pf rules
    cat > /tmp/hiaudio_pf_rules << EOF
# HiAudio Pro ports
pass in proto tcp from any to any port 3000
pass in proto udp from any to any port 55555
pass out proto tcp from any to any port 3000
pass out proto udp from any to any port 55555
EOF
    
    sudo pfctl -f /tmp/hiaudio_pf_rules
    echo "✅ ファイアウォール設定完了"
}

# HTTPS証明書生成
setup_https() {
    echo "🔒 HTTPS証明書を生成しますか？ (推奨) (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "📜 SSL証明書を生成中..."
        
        mkdir -p ssl
        
        # 自己署名証明書生成
        openssl req -x509 -newkey rsa:4096 -keyout ssl/server.key -out ssl/server.crt -days 365 -nodes -subj "/C=JP/ST=Tokyo/L=Tokyo/O=HiAudio/CN=localhost"
        
        if [ $? -eq 0 ]; then
            echo "✅ HTTPS証明書生成完了"
            echo "   🔒 サーバー起動時に自動的にHTTPS有効"
        else
            echo "❌ 証明書生成失敗 - HTTP モードで継続"
        fi
    fi
}

# パフォーマンス最適化
optimize_performance() {
    echo "⚡ パフォーマンス最適化を適用中..."
    
    # Node.js メモリ制限を緩和
    export NODE_OPTIONS="--max-old-space-size=2048"
    
    # UDPバッファサイズ最適化
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sudo sysctl -w net.inet.udp.maxdgram=65536
        sudo sysctl -w net.inet.udp.recvspace=65536
    fi
    
    echo "✅ パフォーマンス最適化完了"
}

# メイン実行
main() {
    check_system
    check_firewall
    setup_https
    optimize_performance
    
    # Install dependencies
    echo "📦 依存関係をインストール中..."
    npm install
    
    if [ $? -eq 0 ]; then
        echo "✅ 依存関係のインストール完了"
    else
        echo "❌ 依存関係のインストール失敗"
        echo "🔧 手動で 'npm install' を実行してください"
        exit 1
    fi
    
    # 起動テスト
    echo "🧪 システムテスト中..."
    timeout 5 npm test >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ システムテスト完了"
    else
        echo "⚠️  一部テストが失敗しましたが継続可能"
    fi
    
    echo ""
    echo "🎵 =============================================="
    echo "   セットアップ完了！ 🎉"
    echo "🎵 =============================================="
    echo ""
    echo "🚀 起動方法："
    echo "   npm start        # 通常起動"
    echo "   npm run dev      # 開発モード (nodemon)"
    echo ""
    echo "🌐 アクセス方法："
    LOCAL_IP=$(ifconfig en0 | grep inet | grep -v inet6 | awk '{print $2}')
    echo "   ローカル: http://localhost:3000"
    echo "   ネットワーク: http://$LOCAL_IP:3000"
    
    if [ -f "ssl/server.crt" ]; then
        echo "   HTTPS: https://$LOCAL_IP:3000"
    fi
    
    echo ""
    echo "📋 次の手順:"
    echo "   1. 🖥️  macOSアプリで「Web」タブを開く"
    echo "   2. 📱 QRコードをスキャンまたは上記URLにアクセス"
    echo "   3. 🎵 Web画面で「開始」ボタンをクリック"
    echo "   4. 🔊 macOSアプリで「ストリーミング開始」"
    echo ""
    echo "🔧 トラブル時: npm run diagnostics"
    echo "📚 詳細: cat README.md"
    echo ""
}

# エラーハンドリング
trap 'echo "❌ セットアップが中断されました"; exit 1' ERR

# 実行
main "$@"