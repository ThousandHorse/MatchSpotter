# トラブルシューティング: "No such module 'GoogleMaps'" エラー

## 問題
ビルド時に「No such module 'GoogleMaps'」エラーが発生する

## 原因
Google Maps SDKのパッケージはプロジェクトに追加されているが、ターゲットにリンクされていない

## 解決方法

### 方法1: Xcodeで手動リンク（推奨）

1. Xcodeでプロジェクトを開く
2. プロジェクトナビゲーターで「MatchSpotter」をクリック
3. TARGETSから「MatchSpotter」を選択
4. 「General」タブを選択
5. 「Frameworks, Libraries, and Embedded Content」セクションまでスクロール
6. 「+」ボタンをクリック
7. 「GoogleMaps」を選択して「Add」
8. Cmd+B でビルド

### 方法2: パッケージキャッシュをクリア

```bash
# ターミナルで実行
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/org.swift.swiftpm
```

その後、Xcodeで：
- File > Packages > Reset Package Caches
- File > Packages > Resolve Package Versions
- File > Packages > Update to Latest Package Versions

### 方法3: パッケージを再追加

1. プロジェクトナビゲーターで「MatchSpotter」をクリック
2. 「Package Dependencies」タブを選択
3. Google Maps SDKを選択して「-」ボタンで削除
4. 「+」ボタンをクリック
5. URL入力: https://github.com/googlemaps/ios-maps-sdk
6. 「Add Package」をクリック
7. 「GoogleMaps」を選択して「Add Package」

### 方法4: Clean Build Folder

Xcode で：
- Product > Clean Build Folder (Shift+Cmd+K)
- 派生データを削除: Xcode > Settings > Locations > Derived Data → 矢印をクリックしてフォルダを開き、削除
- Xcodeを再起動
- プロジェクトを開き直してビルド

## 確認事項

### パッケージが正しく追加されているか確認
```bash
cat MatchSpotter.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

「ios-maps-sdk」が含まれていればOK

### import文の確認
GoogleMapView.swift:
```swift
import SwiftUI
import GoogleMaps        // このimportでエラーが出る
import SwiftData
import CoreLocation
```

## それでも解決しない場合

### 一時的な回避策: Apple MapKitを使用

GoogleMapView.swiftをコメントアウトして、AppleMapView.swift.backupをMapView.swiftにリネーム：

```bash
cd /Users/chibatakuma/Documents/Project/iOS/MatchSpotter/MatchSpotter
mv GoogleMapView.swift GoogleMapView.swift.disabled
mv AppleMapView.swift.backup MapView.swift
```

ContentView.swiftを元に戻す：
```swift
GoogleMapView() → MapView()
```

MatchSpotterApp.swiftからGoogle Maps初期化コードを削除：
```swift
// import GoogleMaps をコメントアウト
// init() { ... } をコメントアウト
```

これでApple MapKitを使った元の実装に戻ります。

## 参考情報

- Google Maps SDK 公式ドキュメント: https://developers.google.com/maps/documentation/ios-sdk/start
- Swift Package Manager: https://github.com/googlemaps/ios-maps-sdk
