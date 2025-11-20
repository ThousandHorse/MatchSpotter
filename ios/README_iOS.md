# MatchSpotter

写真の撮影スポットを管理するiOSアプリケーション

## 概要

**MatchSpotter**は、写真のEXIFデータから位置情報を自動抽出し、撮影場所を地図上で管理できるiOSアプリです。カメラロールから写真を選択するだけで、撮影場所を自動的に特定し、近隣の施設情報も取得できます。

## 主要機能

### 📷 写真スポット登録
- カメラロールから写真を選択
- 写真のEXIFデータからGPS位置情報を自動抽出
- 逆ジオコーディングで場所名を自動取得
- 近隣のお店・施設を自動検索して候補を提示
- 手動での位置情報追加（現在地取得機能）

### 🗺️ 地図表示
- 登録した撮影スポットをマップ上にピン表示
- カスタムカメラアイコンのマーカー
- スポットをタップして詳細を確認
- インタラクティブな地図UI（Google Maps SDK使用）
- 現在地表示、コンパス、ズーム機能搭載

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

## 技術スタック

### プラットフォーム
- iOS 17.0以上
- Swift 5.0
- 100% SwiftUI実装

### 主要フレームワーク
- **SwiftUI** - 宣言的UIフレームワーク
- **SwiftData** - データ永続化（iOS 17の新機能）
- **Google Maps SDK for iOS** - 高機能な地図表示とインタラクティブUI
- **CoreLocation** - GPS位置情報の取得と逆ジオコーディング
- **PhotosUI** - 写真選択機能
- **ImageIO** - EXIF画像メタデータの読み取り

### アーキテクチャ
- MVVM的アーキテクチャ（SwiftUIベース）
- SwiftDataによるリアクティブなデータ管理
- `@Query`によるデータフェッチと自動UI更新
- `@Observable`マクロでの状態管理（iOS 17）

## プロジェクト構造

```
MatchSpotter/
├── MatchSpotterApp.swift          # アプリエントリーポイント
├── Models.swift                   # データモデル定義
│
├── ContentView.swift              # タブバー（地図/リスト）
├── GoogleMapView.swift            # Google Maps地図表示ビュー
├── PhotoSpotListView.swift        # スポット一覧ビュー
├── PhotoSpotDetailView.swift      # スポット詳細ビュー
├── AddPhotoSpotView.swift         # スポット追加ビュー
├── EditPhotoSpotView.swift        # スポット編集ビュー
│
├── Info.plist                     # Google Maps API Key設定
└── Assets.xcassets/               # 画像アセット
```

## データモデル

### PhotoSpot
撮影スポットを表すモデル

```swift
@Model
final class PhotoSpot {
    var name: String           // スポット名
    var latitude: Double       // 緯度
    var longitude: Double      // 経度
    var createdAt: Date        // 作成日時
    @Relationship(deleteRule: .cascade)
    var photos: [PhotoData]    // 関連写真（1対多）
}
```

### PhotoData
写真データを表すモデル

```swift
@Model
final class PhotoData {
    var imageData: Data        // 画像データ
    var caption: String        // キャプション
    var createdAt: Date        // 撮影日時
}
```

## セットアップ

### システム要件
- macOS with Xcode 15.0以上
- iOS 17.0以上のデバイスまたはシミュレーター

### インストール手順

1. リポジトリをクローン
```bash
git clone <repository-url>
cd iOS/MatchSpotter
```

2. Xcodeでプロジェクトを開く
```bash
open MatchSpotter.xcodeproj
```

3. シミュレーターまたは実機でビルド・実行

### 必要な権限

アプリは以下の権限を必要とします（Info.plistに設定済み）:

- **位置情報** (`NSLocationWhenInUseUsageDescription`)
  - GPS情報の取得と逆ジオコーディングに使用

- **写真ライブラリアクセス** (`NSPhotoLibraryUsageDescription`)
  - カメラロールから写真を選択する際に使用

## 使い方

1. **スポットの追加**
   - 「+」ボタンをタップ
   - 写真を選択（EXIF情報から位置を自動取得）
   - または手動で現在地を取得
   - 近隣施設から場所を選択、またはカスタム名を入力
   - 保存

2. **地図で確認**
   - 「地図」タブでピンをタップ
   - スポット詳細を表示

3. **リストで管理**
   - 「リスト」タブでスポット一覧を表示
   - スワイプで編集・削除
   - タップして詳細を確認

4. **写真の追加**
   - スポット詳細から「写真を追加」
   - 複数の写真を同じスポットに追加可能

## 技術的特徴

### EXIF GPS情報の自動抽出
写真のメタデータから位置情報を読み取り、撮影場所を自動的に特定します。

```swift
// AddPhotoSpotView.swift:146-200
CGImageSourceCopyPropertiesAtIndex を使用してEXIF情報を抽出
```

### 逆ジオコーディング
座標から場所名を取得し、優先順位に基づいて表示します（施設名 → 地区名 → 市区町村 → 都道府県）。

```swift
// AddPhotoSpotView.swift:202-228
CLGeocoder().reverseGeocodeLocation で場所名を取得
```

### 近隣施設検索
MapKitのローカル検索APIを使用して、100m圏内の施設を自動検索します。

```swift
// AddPhotoSpotView.swift:230-266
MKLocalSearch で近隣のお店・施設を検索
```

### データの永続化
SwiftDataを使用して、アプリ内データをローカルに保存します。データベース操作は不要で、`@Query`マクロが自動的にデータを取得・更新します。

## 依存関係

### Google Maps SDK for iOS

このプロジェクトはGoogle Maps SDKを使用しています。

- **パッケージマネージャー**: Swift Package Manager
- **リポジトリ**: https://github.com/googlemaps/ios-maps-sdk
- **バージョン**: 10.4.0
- **必要な設定**: Info.plistにAPI Keyの設定が必要

### セットアップ手順

1. Google Cloud Consoleで「Maps SDK for iOS」APIを有効化
2. API Keyを取得
3. `Info.plist`の`GMSApiKey`に取得したAPI Keyを設定

## ライセンス

(ライセンス情報を追加してください)

## 開発者

千葉 拓磨

## Bundle Identifier

```
com.ThousandHorse.MatchSpotter.MatchSpotter
```
# MatchSpotter
