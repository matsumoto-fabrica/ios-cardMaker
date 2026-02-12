# CLAUDE.md - EventCardMaker

## プロジェクト概要
イベント会場でプロ野球カード風のオリジナルカードを作成するiOSアプリ。

## フロー
1. カメラで人物撮影（リアルタイム切り抜きプレビュー付き）
2. 名前入力（英字のみ、文字数制限あり）
3. 背景テンプレート選択
4. カード合成（人物色味調整 + なじませ処理）
5. サーバーアップロード → QRコード表示

## 技術スタック
- **SwiftUI** + iOS 17+
- **Vision framework**: `VNGeneratePersonSegmentationRequest`（リアルタイムプレビュー .fast）、`VNGenerateForegroundInstanceMaskRequest`（最終画像 .accurate）
- **Core Image**: 色味調整・なじませ処理（CIFilter）
- **AVFoundation**: カメラ制御

## アーキテクチャ
- MVVM
- Views/ — SwiftUI画面
- Services/ — カメラ、Vision、画像合成、API通信
- Models/ — データモデル

## ビルド
```bash
xcodegen generate
open EventCardMaker.xcodeproj
```

## 対応端末
- iPhone 11以降（A13+）
- iOS 17+

## フォント
- Google Fonts からバンドル（OFL License）
- スポーツカード風: Bebas Neue, Oswald 等

## 配布
- TestFlight（内部テスター）

## バックエンド（別会社担当）
- POST /cards — カード画像アップロード
- GET /cards — 一覧取得
- 管理画面はWeb（PC）で印刷対応
