# Google Maps SDK 実装ガイド

## 概要

MatchSpotterアプリでは、Apple MapKitの代わりにGoogle Maps SDK for iOSを使用して地図機能を実装しています。

## 実装ファイル

### GoogleMapView.swift

Google Maps SDKを使用した地図表示ビューの実装。

#### 主要コンポーネント

1. **GoogleMapViewRepresentable**
   - `UIViewRepresentable`プロトコルを実装
   - SwiftUIでGoogle Mapsを使用するためのブリッジ
   - GMSMapViewをSwiftUIで扱えるようにラップ

2. **カスタムマーカーアイコン**
   - カメラアイコンを含む円形マーカー
   - 赤い背景色で視認性を確保
   - `UIGraphicsImageRenderer`で動的に生成

3. **インタラクティブ機能**
   - マーカータップでスポット詳細をシート表示
   - カスタム情報ウィンドウ（スポット名、写真枚数表示）
   - 自動的なカメラ位置調整（全マーカーが表示されるように）

#### マップ設定

```swift
mapView.settings.compassButton = true       // コンパスボタン表示
mapView.settings.myLocationButton = true    // 現在地ボタン表示
mapView.isMyLocationEnabled = true          // 現在地表示
mapView.settings.zoomGestures = true        // ズーム操作
mapView.settings.scrollGestures = true      // スクロール操作
mapView.settings.rotateGestures = true      // 回転操作
mapView.settings.tiltGestures = true        // 傾斜操作
```

## セットアップ

### 1. Google Maps SDK のインストール

Swift Package Managerを使用してインストール済み：

```
リポジトリ: https://github.com/googlemaps/ios-maps-sdk
バージョン: 10.4.0
```

### 2. API Keyの設定

`Info.plist`に以下を追加：

```xml
<key>GMSApiKey</key>
<string>YOUR_API_KEY_HERE</string>
```

### 3. SDK の初期化

`MatchSpotterApp.swift`で初期化：

```swift
import GoogleMaps

@main
struct MatchSpotterApp: App {
    init() {
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String {
            GMSServices.provideAPIKey(apiKey)
        }
    }
    // ...
}
```

## 主要機能

### マーカー表示

各撮影スポットに対してカスタムマーカーを生成：

```swift
let marker = GMSMarker()
marker.position = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
marker.title = spot.name
marker.snippet = "\(spot.photos.count)枚の写真"
marker.userData = spot
marker.icon = createCustomMarkerIcon()
marker.map = mapView
```

### カメラ位置の自動調整

すべてのマーカーが表示されるようにカメラを自動調整：

```swift
var bounds = GMSCoordinateBounds()
for spot in photoSpots {
    bounds = bounds.includingCoordinate(spot.coordinate)
}
let update = GMSCameraUpdate.fit(bounds, withPadding: 50.0)
mapView.moveCamera(update)
```

### カスタム情報ウィンドウ

マーカータップ時に表示される情報ウィンドウをカスタマイズ：

```swift
func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
    // スポット名、写真枚数、「タップして詳細を表示」を表示
    // 角丸、影付きのカスタムデザイン
}
```

## Apple MapKitからの移行

### 変更点

| 項目 | MapKit | Google Maps |
|------|--------|-------------|
| インポート | `import MapKit` | `import GoogleMaps` |
| マップビュー | `Map` | `GMSMapView` (UIViewRepresentable) |
| アノテーション | `Annotation` | `GMSMarker` |
| カメラ | `MapCameraPosition` | `GMSCameraPosition` |
| 座標 | `CLLocationCoordinate2D` | `CLLocationCoordinate2D` (共通) |

### 旧実装のバックアップ

元のMapKit実装は`AppleMapView.swift.backup`として保存済み。

## トラブルシューティング

### API Keyエラー

エラーメッセージ: "Google Maps SDK for iOS requires an API key"

**解決方法:**
1. Google Cloud Consoleでプロジェクトを作成
2. 「Maps SDK for iOS」APIを有効化
3. APIキーを作成
4. `Info.plist`の`GMSApiKey`に設定

### マーカーが表示されない

**確認事項:**
1. `marker.map = mapView`が設定されているか
2. 座標値が有効か（緯度: -90〜90, 経度: -180〜180）
3. カメラ位置がマーカーの範囲内にあるか

### ビルドエラー

**一般的な原因:**
1. Google Maps SDKのパッケージが正しくインストールされていない
2. import文が不足している
3. iOS deployment targetが正しく設定されていない（iOS 13.0以上が必要）

## パフォーマンス最適化

### マーカー数が多い場合

1. **クラスタリング**の実装を検討
2. **可視範囲内のマーカーのみ表示**
3. **マーカーアイコンのキャッシュ**

### メモリ使用量の削減

1. カスタムマーカーアイコンを一度だけ生成してキャッシュ
2. 不要なマーカーは`marker.map = nil`で削除

## 参考リンク

- [Google Maps SDK for iOS ドキュメント](https://developers.google.com/maps/documentation/ios-sdk)
- [GitHub リポジトリ](https://github.com/googlemaps/ios-maps-sdk)
- [API Key取得ガイド](https://developers.google.com/maps/documentation/ios-sdk/get-api-key)
