# MatchSpotter

写真の撮影スポットを管理するマルチプラットフォームアプリケーション

## 概要

**MatchSpotter**は、写真のEXIFデータから位置情報を自動抽出し、撮影場所を地図上で管理できるアプリです。カメラロールから写真を選択するだけで、撮影場所を自動的に特定し、地図上にマーカーとして表示します。

## プラットフォーム

### iOS版（実装済み） ✅
- **状態**: リリース可能
- **対応OS**: iOS 17.0以上
- **技術スタック**: SwiftUI, SwiftData, Google Maps SDK
- **ドキュメント**: [ios/README_iOS.md](ios/README_iOS.md)

### Android版（予定） 🚧
- **状態**: 開発予定
- **対応OS**: Android 8.0 (API Level 26) 以上
- **技術スタック**: Kotlin, Jetpack Compose, Google Maps SDK
- **フォルダ**: `android/`

## 主要機能

### 📷 写真スポット登録
- カメラロールから写真を選択
- 写真のEXIFデータからGPS位置情報を自動抽出
- 逆ジオコーディングで場所名を自動取得
- 手動での位置情報追加（現在地取得機能）

### 🗺️ 地図表示
- 登録した撮影スポットをマップ上にピン表示
- カスタムカメラアイコンのマーカー
- スポットをタップして詳細を確認
- Google Maps SDK使用（高機能な地図UI）

### 📋 リスト表示
- 撮影スポットを一覧表示
- サムネイル画像付きのリスト
- スワイプジェスチャーで編集・削除

### ✏️ スポット管理
- スポット情報の編集（名前変更、写真追加）
- スポットの削除（関連写真も一括削除）
- 写真の個別削除

### 🔍 詳細表示
- グリッド形式での写真表示
- フルスクリーン写真ビューア
- キャプションと撮影日時の表示

## プロジェクト構造

```
MatchSpotter/
├── README.md                    # このファイル（プロジェクト全体の説明）
├── .gitignore                   # Git除外設定
│
├── ios/                         # iOSアプリケーション
│   ├── README_iOS.md           # iOS版の詳細ドキュメント
│   ├── MatchSpotter.xcodeproj/ # Xcodeプロジェクト
│   ├── MatchSpotter/           # iOSソースコード
│   │   ├── MatchSpotterApp.swift
│   │   ├── Models.swift
│   │   ├── GoogleMapView.swift
│   │   ├── ContentView.swift
│   │   ├── PhotoSpotListView.swift
│   │   ├── PhotoSpotDetailView.swift
│   │   ├── AddPhotoSpotView.swift
│   │   ├── EditPhotoSpotView.swift
│   │   └── ...
│   ├── GOOGLE_MAPS_IMPLEMENTATION.md
│   └── TROUBLESHOOTING.md
│
└── android/                     # Androidアプリケーション（今後実装）
    └── README_Android.md       # Android版のドキュメント（予定）
```

## データモデル（共通仕様）

### PhotoSpot（撮影スポット）
- `name`: スポット名（String）
- `latitude`: 緯度（Double）
- `longitude`: 経度（Double）
- `createdAt`: 作成日時（Date/Timestamp）
- `photos`: 関連写真のリスト（1対多）

### PhotoData（写真データ）
- `imageData`: 画像データ（Binary/Blob）
- `caption`: キャプション（String, nullable）
- `takenAt`: 撮影日時（Date/Timestamp）
- `photoSpot`: 関連スポット（外部キー）

## セットアップ

### iOS版
詳細は [ios/README_iOS.md](ios/README_iOS.md) を参照してください。

**クイックスタート:**
```bash
cd ios
open MatchSpotter.xcodeproj
```

**必要な設定:**
1. Google Maps API Keyの取得
2. `Info.plist`にAPI Keyを設定
3. Xcodeでビルド・実行

### Android版（今後実装予定）
Coming soon...

## 技術的な特徴

### 共通コンセプト
- **EXIF GPS情報の自動抽出**: 写真のメタデータから位置情報を読み取り
- **逆ジオコーディング**: 座標から場所名を自動取得
- **ローカルデータ永続化**: オフラインでも動作
- **Google Maps統合**: 高機能な地図表示

### プラットフォーム別実装

#### iOS
- **UI**: 100% SwiftUI
- **データ永続化**: SwiftData（iOS 17）
- **地図**: Google Maps SDK for iOS
- **画像処理**: ImageIO (EXIF読み取り)

#### Android（予定）
- **UI**: Jetpack Compose
- **データ永続化**: Room Database
- **地図**: Google Maps SDK for Android
- **画像処理**: ExifInterface

## 開発ロードマップ

### Phase 1: iOS版（完了） ✅
- [x] 基本UI実装（SwiftUI）
- [x] データモデル設計（SwiftData）
- [x] EXIF GPS抽出機能
- [x] 逆ジオコーディング
- [x] Apple MapKit統合
- [x] Google Maps SDK統合
- [x] 写真管理機能
- [x] スポット編集・削除機能

### Phase 2: Android版（予定） 🚧
- [ ] プロジェクトセットアップ（Kotlin + Compose）
- [ ] データモデル実装（Room）
- [ ] EXIF GPS抽出機能
- [ ] Google Maps SDK統合
- [ ] UI実装（Compose）
- [ ] 写真管理機能
- [ ] スポット編集・削除機能

### Phase 3: クロスプラットフォーム連携（将来） 🔮
- [ ] クラウド同期機能（Firebase/Supabase）
- [ ] iOS-Android間でのデータ共有
- [ ] アカウント管理
- [ ] 写真共有機能

## 依存関係

### iOS
- Google Maps SDK for iOS (v10.4.0+)
- Swift Package Manager

### Android（予定）
- Google Maps SDK for Android
- Gradle

## ライセンス

(ライセンス情報を追加してください)

## 開発者

千葉 拓磨

## Bundle Identifier

### iOS
```
com.ThousandHorse.MatchSpotter.MatchSpotter
```

### Android（予定）
```
com.thousandhorse.matchspotter
```

## スクリーンショット

(スクリーンショットを追加してください)

## コントリビューション

プルリクエストを歓迎します！大きな変更の場合は、まずissueを開いて変更内容を議論してください。

## お問い合わせ

バグ報告や機能リクエストは、GitHubのissuesセクションでお願いします。
