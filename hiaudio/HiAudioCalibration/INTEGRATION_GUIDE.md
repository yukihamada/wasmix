# 🔗 HiAudio Pro - キャリブレーション統合ガイド

## 📋 統合計画

このガイドでは、新しいキャリブレーションシステムを既存のHiAudioプロジェクトに統合する手順を説明します。

---

## 🏗️ プロジェクト構造の更新

### 既存構造
```
/Users/yuki/hiaudio/
├── HiAudioSender.xcodeproj      # macOSアプリ
├── HiAudioReceiver.xcodeproj    # iOSアプリ  
├── HiAudioWeb/                  # Web版システム
└── HiAudioCalibration/          # 新キャリブレーションシステム
```

### 統合後構造
```
/Users/yuki/hiaudio/
├── HiAudioSender.xcodeproj      # macOS（キャリブレーション機能追加）
├── HiAudioReceiver.xcodeproj    # iOS（キャリブレーション機能追加）
├── HiAudioWeb/                  # Web版（そのまま）
└── HiAudioCalibration/          # 共通ライブラリ化
    ├── Shared/                   # 共通コンポーネント
    │   ├── SimplifiedCalibrationEngine.swift
    │   ├── CalibrationNetworking.swift  
    │   └── CalibrationDataStructures.swift
    ├── macOS/                   # macOS専用
    │   └── CalibrationServerManager.swift
    ├── iOS/                     # iOS専用
    │   ├── BasicCalibrationUI.swift
    │   └── CalibrationClientManager.swift
    └── Tests/
        └── CalibrationTests.swift
```

---

## 🔧 統合手順

### Step 1: プロジェクト設定更新

#### macOS プロジェクト (HiAudioSender)
```bash
# 1. キャリブレーション関連ファイルを追加
# Xcode > Project Navigator > Right Click > Add Files

# 追加するファイル:
- SimplifiedCalibrationEngine.swift
- CalibrationNetworking.swift
- CalibrationServerManager.swift (新規作成)

# 2. フレームワーク依存関係追加
# Target > Build Phases > Link Binary With Libraries
- Network.framework
- os.framework (logging用)

# 3. 権限設定更新 (Info.plist)
<key>NSMicrophoneUsageDescription</key>
<string>キャリブレーション機能でマイクを使用します</string>
<key>NSNetworkUsageDescription</key>  
<string>デバイス間通信でネットワークを使用します</string>
```

#### iOS プロジェクト (HiAudioReceiver)
```bash
# 1. キャリブレーション関連ファイルを追加
- SimplifiedCalibrationEngine.swift (共通)
- CalibrationNetworking.swift (共通)
- BasicCalibrationUI.swift
- CalibrationClientManager.swift (新規作成)

# 2. フレームワーク依存関係追加
- AVFoundation.framework
- Network.framework
- os.framework

# 3. 権限設定更新 (Info.plist)
<key>NSMicrophoneUsageDescription</key>
<string>音声キャリブレーション測定でマイクを使用します</string>
<key>NSLocalNetworkUsageDescription</key>
<string>macOSデバイスとの通信でローカルネットワークを使用します</string>
```

### Step 2: 共通コンポーネント作成

#### CalibrationDataStructures.swift
```swift
// 共通データ構造体を分離
import Foundation

// デバイス情報
public struct CalibrationDevice: Codable, Identifiable {
    public let id: String
    public let name: String
    public let type: DeviceType
    
    public enum DeviceType: String, Codable {
        case macOS_sender = "macOS"
        case iOS_receiver = "iOS"
    }
}

// キャリブレーション結果
public struct CalibrationResult: Codable {
    public let deviceId: String
    public let measuredDelay: Double
    public let confidence: Float
    public let qualityScore: Float
    public let timestamp: Date
}

// その他共通データ構造...
```

### Step 3: macOS統合コード

#### CalibrationServerManager.swift
```swift
// HiAudioSender への統合管理クラス
import Foundation
import SwiftUI

@MainActor
class CalibrationServerManager: ObservableObject {
    @Published var isRunning = false
    @Published var connectedDevices: [CalibrationDevice] = []
    @Published var calibrationResults: [CalibrationResult] = []
    
    private let calibrationEngine = SimplifiedCalibrationEngine()
    private let networking = CalibrationNetworking()
    
    func startCalibrationServer() async throws {
        try await networking.startServer()
        networking.startDeviceDiscovery()
        isRunning = true
    }
    
    func stopCalibrationServer() async {
        await networking.stopServer()
        isRunning = false
    }
    
    func performCalibrationForDevice(_ deviceId: String) async throws {
        // 実装...
    }
}
```

#### HiAudioSender の ContentView 更新
```swift
// 既存の ContentView.swift に統合
struct ContentView: View {
    @StateObject private var sender = BestSender()
    @StateObject private var calibrationManager = CalibrationServerManager()
    
    var body: some View {
        TabView {
            // 既存のタブ...
            
            // 新しいキャリブレーションタブ
            CalibrationServerView(manager: calibrationManager)
                .tabItem {
                    Image(systemName: "tuningfork")
                    Text("キャリブレーション")
                }
        }
    }
}

struct CalibrationServerView: View {
    @ObservedObject var manager: CalibrationServerManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("iPhone キャリブレーション")
                .font(.title2)
                .fontWeight(.bold)
            
            // サーバーステータス
            HStack {
                Circle()
                    .fill(manager.isRunning ? .green : .red)
                    .frame(width: 12, height: 12)
                Text(manager.isRunning ? "サーバー動作中" : "サーバー停止中")
            }
            
            // 接続デバイス一覧
            if !manager.connectedDevices.isEmpty {
                VStack(alignment: .leading) {
                    Text("接続デバイス:")
                        .font(.headline)
                    
                    ForEach(manager.connectedDevices) { device in
                        HStack {
                            Text(device.name)
                            Spacer()
                            Button("キャリブレーション") {
                                Task {
                                    try? await manager.performCalibrationForDevice(device.id)
                                }
                            }
                        }
                    }
                }
            }
            
            // 制御ボタン
            Button(manager.isRunning ? "サーバー停止" : "サーバー開始") {
                Task {
                    if manager.isRunning {
                        await manager.stopCalibrationServer()
                    } else {
                        try? await manager.startCalibrationServer()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

### Step 4: iOS統合コード

#### CalibrationClientManager.swift
```swift
// HiAudioReceiver への統合管理クラス
import Foundation
import SwiftUI

@MainActor
class CalibrationClientManager: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var calibrationStatus: CalibrationStatus = .idle
    @Published var lastResult: CalibrationResult?
    
    private let calibrationEngine = SimplifiedCalibrationEngine()
    private let networking = CalibrationNetworking()
    
    enum ConnectionStatus {
        case disconnected, connecting, connected
    }
    
    enum CalibrationStatus {
        case idle, running, completed, error
    }
    
    func connectToMacOS(host: String) async throws {
        connectionStatus = .connecting
        try await networking.connectToServer(host: host)
        connectionStatus = .connected
    }
    
    func startCalibration() async throws {
        calibrationStatus = .running
        
        // キャリブレーション実行...
        
        calibrationStatus = .completed
    }
}
```

#### HiAudioReceiver の ContentView 更新
```swift
// 既存の ContentView.swift に統合
struct ContentView: View {
    @StateObject private var receiver = BestReceiver()
    @StateObject private var calibrationManager = CalibrationClientManager()
    
    var body: some View {
        TabView {
            // 既存のタブ...
            
            // 新しいキャリブレーションタブ
            BasicCalibrationView()
                .environmentObject(calibrationManager)
                .tabItem {
                    Image(systemName: "tuningfork")
                    Text("キャリブレーション")
                }
        }
    }
}
```

---

## 🧪 統合テスト計画

### Phase 1: ビルド・基本動作確認

#### macOS テスト
```bash
# 1. Xcodeでプロジェクトを開く
open HiAudioSender.xcodeproj

# 2. キャリブレーション関連ファイルが正しく追加されているか確認
# 3. ビルドエラーがないか確認 (⌘+B)
# 4. 基本的なUI表示確認
# 5. サーバー開始/停止の動作確認
```

#### iOS テスト  
```bash
# 1. Xcodeでプロジェクトを開く
open HiAudioReceiver.xcodeproj

# 2. キャリブレーション関連ファイルが正しく追加されているか確認
# 3. ビルドエラーがないか確認 (⌘+B)
# 4. シミュレータでの基本UI確認
# 5. 実機での権限要求動作確認
```

### Phase 2: 統合機能テスト

#### 接続テスト
```bash
# テスト手順
1. macOS: HiAudioSender起動 → キャリブレーションタブ → サーバー開始
2. iOS: HiAudioReceiver起動 → キャリブレーションタブ → 接続設定
3. 同一Wi-Fi環境での接続確認
4. 接続状態の正しい表示確認
5. 切断・再接続の動作確認
```

#### キャリブレーション動作テスト
```bash
# テスト手順
1. macOS-iOS接続確立
2. iOS側で「キャリブレーション開始」
3. 処理プロセスの正常動作確認
4. 結果表示の正確性確認
5. macOS側での結果表示確認
```

### Phase 3: エラーハンドリング統合テスト

#### ネットワークエラー
```bash
# テスト項目
- Wi-Fi切断時の動作
- サーバー停止時の動作  
- 接続タイムアウト時の動作
- 不正なIPアドレス指定時の動作
```

#### キャリブレーションエラー
```bash
# テスト項目
- マイク権限拒否時の動作
- 雑音が大きい環境での動作
- 音声信号検出失敗時の動作
- 処理中断時の動作
```

---

## 📊 統合後のテスト結果評価

### 成功基準
- ✅ **ビルド成功率**: 100%（警告なし）
- ✅ **基本機能動作**: 100%（UI表示・画面遷移）
- ✅ **接続成功率**: 90%以上（理想環境）
- ✅ **キャリブレーション成功率**: 80%以上（一般環境）
- ✅ **エラーハンドリング**: 100%（適切なエラー表示）

### 品質チェックリスト
```markdown
## macOS統合チェック
- [ ] プロジェクトがエラーなしでビルド可能
- [ ] キャリブレーションタブが正しく表示
- [ ] サーバー開始/停止が動作
- [ ] 接続デバイス一覧が更新される  
- [ ] 既存機能（音声送信）に影響なし

## iOS統合チェック  
- [ ] プロジェクトがエラーなしでビルド可能
- [ ] キャリブレーションタブが正しく表示
- [ ] macOSサーバーへの接続が可能
- [ ] キャリブレーション処理が完了
- [ ] 結果が正しく表示される
- [ ] 既存機能（音声受信）に影響なし

## 統合機能チェック
- [ ] macOS-iOS間でデータ交換が正常
- [ ] エラーが適切にハンドリングされる
- [ ] パフォーマンスが許容範囲内
- [ ] メモリリークが発生しない
- [ ] 長時間動作が安定
```

---

## 🚀 デプロイメント計画

### Step 1: 開発版配布
```bash
# macOS
1. Archive → Export → Development Distribution
2. .app ファイルを開発チーム内配布
3. 基本動作の検証

# iOS
1. Archive → Export → Development Distribution  
2. TestFlight または Ad Hoc 配布
3. 実機での基本動作検証
```

### Step 2: ベータテスト
```bash
# 対象者
- 開発チーム: 2-3名
- 早期ユーザー: 5-10名
- 音響専門家: 2-3名

# テスト期間: 1-2週間
# フィードバック収集方法: 
- Slack/Discord での直接フィードバック
- TestFlight レビュー機能
- Google Forms でのアンケート
```

### Step 3: 本番リリース準備
```bash
# リリース前チェック
- [ ] 全機能テストの完了
- [ ] ドキュメントの完備
- [ ] App Store / 配布準備
- [ ] サポート体制の整備
```

---

## 📚 ドキュメント更新

### 更新が必要なドキュメント

#### README.md
```markdown
# 追加セクション
## キャリブレーション機能
HiAudio Pro v2.0では、iPhoneマイクロフォンの高精度キャリブレーション機能を追加しました。

### 機能概要
- macOS-iPhone間でのワイヤレス音響測定
- 1-2ms精度の遅延測定
- 簡単な操作でプロ級の測定結果

### 使用方法
1. macOS: HiAudioSender → キャリブレーションタブ
2. iPhone: HiAudioReceiver → キャリブレーションタブ  
3. 接続確立後、キャリブレーション実行

詳細は [CALIBRATION_SPECIFICATION.md](HiAudioCalibration/CALIBRATION_SPECIFICATION.md) を参照。
```

#### ROADMAP.md
```markdown
# 完了項目に追加
## v2.0 - iPhone マイクロフォン キャリブレーション ✅
- [x] 高精度遅延測定エンジン
- [x] macOS-iOS通信システム  
- [x] 直感的なユーザーインターフェース
- [x] 包括的なテスト実装
- [x] 実機動作検証
```

#### DEPLOYMENT.md
```markdown
# 新規作成または更新
## キャリブレーション機能のデプロイメント

### 前提条件
- Xcode 15.0以降
- macOS 13.0以降（開発機）
- iOS 15.0以降対応デバイス

### ビルド手順
1. キャリブレーション関連ファイルの統合確認
2. 依存フレームワークの追加確認
3. 権限設定の更新確認
4. テストの実行・パス確認

### 配布方法
- macOS: 直接配布または Mac App Store
- iOS: TestFlight または App Store
```

---

## ⚠️ 注意事項・制限事項

### 技術的制限
- **ネットワーク要件**: 同一Wi-Fi必須（クロスネットワーク未対応）
- **同時デバイス数**: 最大5台推奨（性能制限）
- **対応プラットフォーム**: macOS 13+, iOS 15+のみ
- **精度限界**: 1-2ms（0.1ms精度は非対応）

### 運用上の注意
- **初回実行時**: マイク・ネットワーク権限の要求あり
- **環境要件**: 静音環境推奨（SNR 15dB以上）
- **ネットワーク**: 有線LAN推奨（Wi-Fiは品質により変動）
- **サポート**: コミュニティベース（商用サポートなし）

### 既知の課題
- **Bluetoothオーディオ**: 遅延が大きく測定に不適
- **古いデバイス**: iPhone X以前は精度低下の可能性
- **高負荷時**: 他アプリの影響でタイミング精度低下
- **温度変化**: 長時間使用時の発熱による影響

---

## 📞 サポート・トラブルシューティング

### FAQ（よくある質問）

**Q: キャリブレーション機能が見つからない**
```
A: HiAudio Pro v2.0以降で利用可能です。
   macOS: HiAudioSender のキャリブレーションタブ
   iOS: HiAudioReceiver のキャリブレーションタブ
```

**Q: 接続できない**
```
A: 以下を確認してください：
   1. 同じWi-Fiネットワークに接続
   2. ファイアウォール設定でポート55557を許可
   3. macOS側でサーバーが起動中か確認
   4. 診断機能でネットワーク状態を確認
```

**Q: 精度が悪い**
```
A: 以下を試してください：
   1. より静かな環境で実行
   2. デバイス間距離を30cm-1mに調整
   3. 有線LAN接続に変更
   4. 複数回実行して最良結果を採用
```

### 報告・フィードバック先
- **GitHub Issues**: https://github.com/[your-org]/hiaudio/issues
- **Discord**: HiAudio Community Server
- **Email**: support@hiaudio.pro

---

## 🎉 統合完了チェックリスト

### 最終確認項目
- [ ] **macOSプロジェクト統合完了**
  - [ ] ファイル追加確認
  - [ ] ビルド成功確認  
  - [ ] 機能動作確認
  
- [ ] **iOSプロジェクト統合完了**
  - [ ] ファイル追加確認
  - [ ] ビルド成功確認
  - [ ] 実機動作確認
  
- [ ] **統合テスト完了**
  - [ ] 接続テスト
  - [ ] キャリブレーション動作テスト
  - [ ] エラーハンドリングテスト
  
- [ ] **ドキュメント更新完了**
  - [ ] README更新
  - [ ] 仕様書作成
  - [ ] 使用方法ガイド作成
  
- [ ] **品質保証完了**
  - [ ] 全テストパス
  - [ ] パフォーマンス確認
  - [ ] メモリリーク確認

### リリース準備完了の確認
- [ ] **機能動作**: 基本機能が確実に動作
- [ ] **品質基準**: 精度・速度・信頼性が基準達成
- [ ] **ユーザビリティ**: 非技術者でも使用可能
- [ ] **ドキュメント**: 使用方法が明確に説明
- [ ] **サポート体制**: 問題対応の仕組み整備

---

*🔗 統合ガイド v1.0 - HiAudio Pro Calibration System Integration*  
*📅 作成日: 2024年11月21日*