#!/usr/bin/env swift

import Foundation
import AVFoundation

// シンプルなMac用オーディオテスト
print("🎵 HiAudio Mac Sender テスト開始")

// 1. AVAudioEngine初期化テスト
let engine = AVAudioEngine()
print("✅ AVAudioEngine 初期化完了")

// 2. Input Node テスト
let inputNode = engine.inputNode
print("✅ Input Node 取得完了: \(inputNode)")

// 3. オーディオセッション設定テスト
do {
    try engine.start()
    print("✅ Audio Engine 開始成功")
    engine.stop()
    print("✅ Audio Engine 停止成功")
} catch {
    print("❌ Audio Engine エラー: \(error)")
}

print("🎵 基本テスト完了")