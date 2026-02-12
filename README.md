# EventCardMaker 🎴

イベント会場でプロ野球カード風のオリジナルカードを作成するiOSアプリ。

## 概要

来場者を撮影し、背景を自動切り抜き → テンプレートと合成 → カード画像を生成します。
Apple Vision frameworkのリアルタイム人物セグメンテーションを活用。

## フロー

```
📷 撮影 → ✏️ 名前入力 → 🎨 テンプレート選択 → 🖼️ カード合成 → 📤 アップロード → QR表示
```

## 機能

### カメラ（モック検証用）
- **リアルタイム人物切り抜きプレビュー** — RAW / SEGMENTED 2画面比較
- **精度切り替え** — Fast / Balanced / Accurate をワンタップ切替
- **マスク閾値スライダー** — 切り抜きの厳しさをリアルタイム調整（0.1〜0.95）
- **FPSカウンター** — リアルタイム実測FPS表示
- **フロント/リアカメラ切り替え**
- **バースト撮影** — 3フレームから最良の切り抜きを自動選択

### カード作成
- **名前入力** — アルファベットのみ、20文字制限
- **テンプレート選択** — 4種類のカードデザイン（横スクロール）
- **カード合成** — 人物色味調整（彩度・コントラスト・明度）でなじませ処理
- **カードサイズ** — プロ野球カード比率（63:88mm）

### アップロード・共有
- サーバーにアップロード → QRコード表示（モック）
- 管理画面（Web/PC）から印刷可能（別会社担当）

## 技術スタック

| 技術 | 用途 |
|------|------|
| **SwiftUI** | UI |
| **Vision framework** | 人物セグメンテーション |
| **AVFoundation** | カメラ制御 |
| **Core Image** | 画像合成・色味調整・マスク閾値処理 |
| **Core Graphics** | カードレイアウト描画 |

### セグメンテーション戦略

| 場面 | API | 精度モード |
|------|-----|-----------|
| リアルタイムプレビュー | `VNGeneratePersonSegmentationRequest` | `.fast` / `.balanced` / `.accurate` 切替可 |
| 最終撮影画像 | `VNGenerateForegroundInstanceMaskRequest` | 最高精度 |

### パフォーマンス実測値（iPhone SE3 / A15）

| モード | FPS |
|--------|-----|
| Fast | 30+ |
| Balanced | 15-20 |
| Accurate | **11** |

※ iPhone 15 Pro (A17 Pro) ではさらに高速。

## 要件

- **iOS 17.0+**
- **iPhone 11以降**（A13 Bionic+）
- **Xcode 16+**
- **Apple Developer Program**（実機ビルド用）

## セットアップ

```bash
# XcodeGenでプロジェクト生成
brew install xcodegen
xcodegen generate

# Xcodeで開く
open EventCardMaker.xcodeproj
```

1. Xcode → Signing & Capabilities → Team を設定
2. iPhoneを接続 → ビルドターゲットに実機を選択
3. ⌘+R でビルド＆実行

※ カメラはシミュレータでは動作しません。実機必須。

## プロジェクト構成

```
EventCardMaker/
├── EventCardMakerApp.swift     # エントリーポイント
├── Models/
│   └── CardData.swift          # データモデル
├── Views/
│   ├── ContentView.swift       # フロー制御（ステップ管理）
│   ├── CameraView.swift        # カメラ画面（2画面比較・精度切替・閾値）
│   ├── NameInputView.swift     # 名前入力画面
│   ├── TemplateSelectView.swift # テンプレート選択画面
│   ├── CardPreviewView.swift   # カード合成プレビュー
│   └── CompleteView.swift      # 完了・QRコード表示
├── Services/
│   ├── CameraService.swift     # カメラ + Vision + セグメンテーション
│   └── ImageCompositor.swift   # カード画像合成エンジン
└── Assets.xcassets/

.claude/
└── agents/                     # Claude Code エージェントチーム
    ├── project-leader.md       # PM: タスク管理・進行
    ├── tech-director.md        # 技術選定・設計判断
    ├── coder.md                # 実装担当
    └── reviewer.md             # コードレビュー
```

## 配布

TestFlight（内部テスター）で配布。

## TODO

- [ ] サーバーAPI連携（アップロード）
- [ ] QRコード生成（実装）
- [ ] カスタムフォント（Google Fonts バンドル）
- [ ] テンプレート画像の本番デザイン
- [ ] 2台構成対応（受付iPad + 撮影iPhone）

## ライセンス

Private — Fabrica Inc.
