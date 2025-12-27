# CLAUDE.md

このファイルは、このリポジトリのコードを扱う際にClaude Code (claude.ai/code) にガイダンスを提供します。

---

## プロジェクト概要

**MatchSpotter** は、写真のEXIFデータからGPS情報を自動抽出し、**都道府県 → 場所 → お店**の3階層で撮影場所を管理するiOS写真位置管理アプリです。ローカルのSwiftDataストレージとFirebaseクラウド共有機能を組み合わせたハイブリッドアーキテクチャを採用しています。

### 主要技術
- **iOS 17.0+** with 100% SwiftUI
- **SwiftData**（ローカル永続化）
- **Firebase** (Auth, Firestore, Storage)（クラウド共有）
- **Google Maps SDK for iOS**（地図表示）
- **CoreLocation**（GPS・逆ジオコーディング）

### バンドル識別子
`com.ThousandHorse.MatchSpotter.MatchSpotter`

---

## ビルドと実行

### ビルドコマンド
```bash
# シミュレータ用ビルド
xcodebuild -scheme MatchSpotter -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build

# クリーンビルド
xcodebuild -scheme MatchSpotter -sdk iphonesimulator clean build

# テスト実行
xcodebuild -scheme MatchSpotter -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' test
```

### Xcodeで開く
```bash
open MatchSpotter.xcodeproj
```

### 必須設定
- **Google Maps API Key**: `Info.plist`の`GMSApiKey`に設定
- **Firebase設定**: `GoogleService-Info.plist`が必要
- **権限**: 位置情報 (`NSLocationWhenInUseUsageDescription`) とフォトライブラリ (`NSPhotoLibraryUsageDescription`) は設定済み

---

## アーキテクチャ

### データレイヤー - デュアルストレージアーキテクチャ

アプリは**ローカル + クラウド**の二重構造でデータを管理します。

#### ローカルストレージ (SwiftData)
```
Prefecture (都道府県) → Location (場所) → PhotoData (写真)
```

**主要モデル:**
- `Prefecture`: 都道府県フォルダ（第1階層）
  - `name`: 都道府県名
  - `locations`: 子の場所フォルダ（カスケード削除）
  - `totalPhotoCount`: 計算プロパティで全写真数を取得

- `Location`: 場所フォルダ（第2階層）
  - `name`: 場所名
  - `latitude`, `longitude`: 座標（オプション）
  - `prefecture`: 親の都道府県への参照
  - `photos`: 関連写真（カスケード削除）

- `PhotoData`: 写真データ（第3階層）
  - `imageData`: 画像バイナリデータ
  - `title`: お店名（タイトル）
  - `caption`: キャプション
  - `takenAt`: 撮影日時
  - `latitude`, `longitude`: 座標
  - `location`: 親の場所への参照
  - `firestoreId`: Firestore同期用ID（重複排除に使用）

#### クラウドストレージ (Firebase)

**Firestore コレクション:**
```
- sharedPhotos: 共有写真データ
- users: ユーザー情報
- inviteCodes: 招待コード（管理者機能）
```

**Firebase Storage:**
```
/photos/{userId}/{photoId}.jpg
```

**SharedPhoto モデル:**
- `imageURL`, `thumbnailURL`: Storage画像URL
- `title`, `caption`: タイトル・キャプション
- `latitude`, `longitude`, `hasLocation`: 位置情報
- `locationName`, `prefectureName`: 場所・都道府県名
- `userId`, `userName`: アップロードユーザー
- `takenAt`, `uploadedAt`: 撮影・アップロード日時
- `likes`, `likedBy`: いいね機能（将来実装予定）

#### 統合モデル（Unified Models）

ローカルとクラウドデータをシームレスに統合:

- `UnifiedPrefecture`: ローカルPrefecture + Firestore写真数を統合
- `UnifiedLocation`: ローカルLocation + その場所のFirestore写真を統合
- `UnifiedPhoto`: ローカル写真またはFirestore写真をenumで表現
  - `.local(PhotoData)`: ローカル専用写真
  - `.shared(SharedPhoto)`: Firebase共有写真

**重要:** 自分がアップロードした写真は、ローカル版を優先利用してFirebase Storage料金を削減します。

### 写真の重複排除メカニズム

1. Firestoreアップロード時: `PhotoData.firestoreId`にドキュメントIDを保存
2. 統合処理時: `firestoreId`が一致する写真は重複として扱わない
3. フォールバック: タイトル + タイムスタンプ（10秒許容）でマッチング

---

## コアサービス

### FirebaseManager (`Services/FirebaseManager.swift`)
- すべてのFirestore操作を管理するシングルトン
- 認証状態を処理
- フィルタリング付きのページネーション写真クエリを提供（ユーザー、場所、都道府県別）
- 権限チェック付きの写真削除を管理（自分の写真のみ削除可能）

### FirebaseStorageManager (`Services/FirebaseStorageManager.swift`)
- Firebase Storageへの画像アップロードを処理
- アップロード進捗の追跡を管理
- アップロードされた写真のFirestoreドキュメントを作成

### AuthenticationManager (`Services/AuthenticationManager.swift`)
- Firebase認証状態を管理
- 管理者ロールチェックを処理
- Apple Sign-In統合

### ImageCacheManager (`Services/ImageCacheManager.swift`)
- ダウンロードしたFirebase Storage画像をローカルにキャッシュ
- 古いキャッシュの自動クリーンアップ（30日以上）
- 自分がアップロードした写真はローカル版を優先利用

### InviteService (`Services/InviteService.swift`)
- 招待コードの生成・検証・管理

---

## ビュー階層

### 3階層フォルダナビゲーション

**第1階層: PrefectureListView**
- 都道府県と写真数を表示
- ローカル + Firestore統合データ

**第2階層: LocationListView**
- 都道府県内の場所と写真数を表示
- 位置情報がある場所は座標も表示

**第3階層: UnifiedPhotoListView**
- 場所の名前（お店名）でグループ化された写真を表示
- `title`フィールド（店名）で写真をグループ化
- 各グループは**PlacePhotosGridView**に遷移

**第4階層: PlacePhotosGridView**
- 特定の場所の写真をグリッド表示
- 各写真に`UnifiedPhotoGridItemView`を使用
- 最後の写真が削除されると自動で閉じる

### マップビュー

**GoogleMapView**
- すべての写真位置をカスタムカメラマーカーで表示するメインマップタブ
- ピンタップで写真詳細を表示
- 現在地・コンパス・ズーム操作対応

**AppleMapView**
- デバッグ用代替（DEBUGビルドのみ）
- `@AppStorage("useAppleMap")`で切り替え可能

**MapSelectionView**
- GPSデータがない写真の手動ピン配置

### 写真追加フロー

**AddLocationView**
- 最初の写真で新しい場所を追加
- EXIF GPSデータから自動位置判定
- 逆ジオコーディングで都道府県を自動設定

**AddPhotoToLocationView**
- 既存の場所に写真を追加

**AddPhotoToPlaceView**
- 特定の場所に写真を追加（店名を自動入力）
- 複数写真の一括選択対応
- EXIF GPS抽出・手動座標設定対応
- 参考実装: `AddPhotoToPlaceView.swift:225-310`（EXIF GPS抽出処理）

### 認証フロー

**LoginView**
- Apple Sign-In認証

**SignUpView**
- 招待コード入力
- 新規ユーザー登録

### 管理者機能（管理者のみ表示）

**AdminInviteCodeView**
- 招待コード生成・管理
- 使用状況の確認

---

## 主要ヘルパー

### LocationHelper (`Helpers/LocationHelper.swift`)
- `getOrCreateLocation()`: Prefecture → Location階層を検索または作成
- Firestoreのみの場所の写真を作成する際に使用

### EXIFExtractor (`Helpers/EXIFExtractor.swift`)
- 写真のEXIFデータからGPS座標とタイムスタンプを抽出
- 位置と日付を含む`PhotoMetadata`を返す

---

## 重要なパターン

### 写真削除とリスト更新（ダブルリフレッシュパターン）

共有写真が削除される際の処理フロー:

1. `SharedPhotoDetailView`が`FirebaseManager.deletePhoto()`を呼び出す
2. `onDelete`コールバックをトリガー
3. 親ビューが`removeSharedPhotoFromList()`を呼び出し、以下を実行:
   - ローカル配列から即座に削除（即座にUI更新）
   - `loadUnifiedPhotos()`を呼び出してFirestoreから再取得
4. 詳細ビューから戻る場合、`.onAppear`が`refreshTrigger.toggle()`をトリガー
5. `.task(id: refreshTrigger)`が`loadUnifiedPhotos()`を再実行

**このダブルリフレッシュパターンにより、削除された写真が古いまま表示されることを防ぎます。**

### ビュー間更新のコールバックパターン

親ビューは`onPhotoDeleted: (String?) -> Void`コールバックを下位に渡します:

```
UnifiedPhotoListView
  → PlacePhotosGridView (onPhotoDeleted)
    → UnifiedPhotoGridItemView (onPhotoDeleted)
      → SharedPhotoDetailView (onDelete)
```

階層の深い場所で写真が削除されると、コールバックが上位に伝播してリスト更新をトリガーします。

### EXIF GPS抽出

`PhotosPicker`で選択された写真は以下のように処理されます:

1. `loadTransferable(type: Data.self)`で写真データを読み込み
2. `CGImageSourceCreateWithData()`を使用してEXIFにアクセス
3. `kCGImagePropertyGPSDictionary`からGPS座標を抽出
4. `kCGImagePropertyExifDateTimeOriginal`からタイムスタンプを抽出
5. 半球参照を処理（緯度はN/S、経度はE/W）

完全な実装については`AddPhotoToPlaceView.swift:225-310`を参照してください。

---

## Firebaseルールコンテキスト

### Firestoreセキュリティルール (`firestore.rules`)
- 写真はユーザースコープ：ユーザーは自分の写真のみ削除可能
- `userId`フィールドは書き込み時に検証される
- 場所/都道府県フィールドはクエリ用にインデックス化

### Storageルール (`storage.rules`)
- 写真は`/photos/{userId}/{photoId}.jpg`に保存
- ユーザーは自分のユーザーフォルダにのみアップロード可能
- ユーザーは自分の写真のみ削除可能

---

## パフォーマンス最適化

### 画像キャッシュ戦略
1. **自分がアップロードした写真はローカル版を優先**（Storage料金削減）
2. Firebase Storage画像は初回ダウンロード後にキャッシュ
3. 30日以上前のキャッシュは自動削除

実装: `UnifiedPhoto.getImageData(currentUserId:localPhotos:)` メソッド

### Firestore永続化
```swift
let settings = FirestoreSettings()
settings.isPersistenceEnabled = true
db.settings = settings
```
オフライン対応を強化し、ローカルキャッシュによる高速読み込みを実現

### ページネーション
- Firestore写真クエリは20件ずつページング
- 無限スクロール対応

---

## 一般的な開発タスク

### ナビゲーションに新しいビューを追加

1. `ios/MatchSpotter/Views/`にSwiftUIビューファイルを作成
2. Firebaseデータが必要な場合、`@ObservedObject private var firebaseManager = FirebaseManager.shared`を注入
3. ローカルデータが必要な場合、`@Query`マクロを使用（例：`@Query private var allPrefectures: [Prefecture]`）
4. 親ビューから`NavigationLink`を追加

### 新しいFirebaseコレクションを追加

1. `Models/FirebaseModels.swift`にモデルを定義
2. `FirebaseManager.swift`にクエリメソッドを追加
3. `firestore.rules`のFirestoreセキュリティルールを更新
4. ルールをデプロイ：`firebase deploy --only firestore:rules`

### データ問題のデバッグ

DEBUGビルドでデバッグビューを有効化：
- **SettingsView** - マップ切替、キャッシュ統計、ログアウトを表示
- **FirestoreDiagnosticView** - 生のFirestoreデータ検査

設定タブ経由でアクセス（DEBUGビルドのみ表示）。

---

## Gitワークフロー

### 現在のブランチ構造
- `main` - 本番リリース
- `develop` - 開発用メインブランチ
- `release/*` - リリース候補ブランチ
- 機能ブランチはPR経由で`develop`または`release/*`にマージ

### マージ戦略

**このプロジェクトではrebaseではなくmergeを使用:**

```bash
# 最初にローカル変更をコミット
git add .
git commit -m "Description"

# その後マージでプル（このプロジェクトではrebaseではなく）
git pull origin <branch> --no-rebase

# 競合がある場合、解決してコミット
git add .
git commit -m "Merge remote changes"
```

---

## テスト

### テストターゲット
`MatchSpotterTests/`
- モデルとヘルパーのユニットテスト
- Firebase操作の統合テスト（テスト設定が必要）

### 手動テストチェックリスト
- [ ] GPSデータあり/なしでの写真追加
- [ ] 写真削除とリスト自動更新
- [ ] マップピン配置（GPSからの自動+手動調整）
- [ ] Firestore同期（アップロード、ダウンロード、重複排除）
- [ ] 認証フロー（ログイン、ログアウト、招待コード）
- [ ] 管理者機能（招待コード生成）

---

## デバッグ機能（DEBUG ビルドのみ）

### 設定画面（SettingsView）
- Google Maps / Apple Maps 切り替え
- 画像キャッシュサイズ確認
- ログアウト

### Firestore診断画面（FirestoreDiagnosticView）
- Firestore生データの閲覧
- クエリデバッグ

### アクセス方法
タブビューの設定タブから（DEBUG ビルドでのみ表示）

---

## 主要画面一覧

### 認証関連
- `LoginView.swift` - Apple Sign-In認証
- `SignUpView.swift` - 招待コード入力

### メインタブ
- `ContentView.swift` - 地図・リスト・設定タブ
- `GoogleMapView.swift` - 写真位置マップ表示
- `AppleMapView.swift` - デバッグ用マップ（DEBUG）

### 3階層ナビゲーション
- `PrefectureListView.swift` - 第1階層（都道府県）
- `LocationListView.swift` - 第2階層（場所）
- `UnifiedPhotoListView.swift` - 第3階層（お店別グループ）
- `PlacePhotosGridView.swift` - お店の写真一覧

### 写真追加
- `AddLocationView.swift` - 新規場所作成
- `AddPhotoToLocationView.swift` - 既存場所に追加
- `AddPhotoToPlaceView.swift` - お店に写真追加
- `UploadPhotoView.swift` - Firestoreへアップロード

### 編集・管理
- `EditLocationView.swift` - 場所名・座標編集
- `MapLocationPickerView.swift` - 地図で位置選択
- `AdminInviteCodeView.swift` - 招待コード管理（管理者のみ）

### デバッグ（DEBUG）
- `SettingsView.swift` - 設定・キャッシュ確認
- `FirestoreDiagnosticView.swift` - Firestore生データ確認

---

## 今後の拡張予定

- Android版の実装（Jetpack Compose + Room + Google Maps SDK）
- いいね機能の完全実装
- ユーザー間写真共有機能の拡張
- コメント機能
- 写真検索・フィルタリング機能の強化

---

## 参考ドキュメント

- 詳細仕様書: `SPECIFICATION.md`
- プロジェクト概要: `README.md`
- iOS詳細: `ios/README_iOS.md`
