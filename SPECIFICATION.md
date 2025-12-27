# MatchSpotter 仕様書

本書は、写真撮影スポット管理アプリ **MatchSpotter** の現行仕様を詳細に記載したドキュメントです。iOS版の実装済み仕様を中心に、最新のアーキテクチャと機能を網羅しています。

---

## 1. プロダクト概要

### 1.1 目的
写真のEXIF情報から撮影位置を自動抽出し、**都道府県 → 場所 → お店**の3階層で写真を整理・管理できるアプリ。ローカルストレージとFirebaseクラウドを組み合わせたハイブリッド構成により、個人利用と写真共有の両方をサポートします。

### 1.2 プラットフォーム
- **iOS**: 実装済み（iOS 17.0+）
- **Android**: 開発予定

### 1.3 主要技術スタック
- **iOS**:
  - 100% SwiftUI
  - SwiftData（ローカル永続化）
  - Firebase Auth（Apple Sign-In認証）
  - Firebase Firestore（クラウド写真データベース）
  - Firebase Storage（クラウド画像ストレージ）
  - Google Maps SDK for iOS（地図表示）
  - CoreLocation（GPS・逆ジオコーディング）

---

## 2. アーキテクチャ

### 2.1 データレイヤー - デュアルストレージアーキテクチャ

MatchSpotterは**ローカル + クラウド**の二重構造でデータを管理します。

#### ローカルストレージ（SwiftData）
```
Prefecture（都道府県） → Location（場所） → PhotoData（写真）
```

**モデル定義:**
- `Prefecture`: 都道府県フォルダ（第1階層）
  - `name`: 都道府県名
  - `locations`: 子の場所フォルダ（カスケード削除）
  - `totalPhotoCount`: 全写真数

- `Location`: 場所フォルダ（第2階層）
  - `name`: 場所名
  - `latitude`, `longitude`: 座標（オプション）
  - `prefecture`: 親の都道府県
  - `photos`: 関連写真（カスケード削除）

- `PhotoData`: 写真データ（第3階層）
  - `imageData`: 画像バイナリデータ
  - `title`: お店名（タイトル）
  - `caption`: キャプション
  - `takenAt`: 撮影日時
  - `latitude`, `longitude`: 座標
  - `location`: 親の場所
  - `firestoreId`: Firestore同期用ID（重複排除に使用）

#### クラウドストレージ（Firebase）

**Firestore コレクション:**
- `sharedPhotos`: 共有写真データ
- `users`: ユーザー情報
- `inviteCodes`: 招待コード（管理者機能）

**Firebase Storage:**
- `/photos/{userId}/{photoId}.jpg`: ユーザーごとの画像ファイル

**モデル定義（Firestore）:**
- `SharedPhoto`:
  - `imageURL`, `thumbnailURL`: Storage画像URL
  - `title`, `caption`: タイトル・キャプション
  - `latitude`, `longitude`, `hasLocation`: 位置情報
  - `locationName`, `prefectureName`: 場所・都道府県名
  - `userId`, `userName`: アップロードユーザー
  - `takenAt`, `uploadedAt`: 撮影・アップロード日時
  - `likes`, `likedBy`: いいね機能

### 2.2 統合モデル（Unified Models）

ローカルとFirestoreデータをシームレスに統合するためのラッパーモデル:

- `UnifiedPrefecture`: ローカル都道府県 + Firestore写真数を統合
- `UnifiedLocation`: ローカル場所 + Firestore写真を統合
- `UnifiedPhoto`: ローカル写真またはFirestore写真をenumで表現
  - `.local(PhotoData)`: ローカル専用写真
  - `.shared(SharedPhoto)`: Firebase共有写真
  - 自分がアップロードした写真は**ローカル版を優先利用**してStorage料金を削減

### 2.3 写真の重複排除メカニズム

1. 写真をFirestoreにアップロード時、ローカルの`PhotoData.firestoreId`にドキュメントIDを保存
2. 統合処理時、`firestoreId`が一致する写真は重複として扱わない
3. フォールバック: タイトル + タイムスタンプ（10秒許容）でマッチング

---

## 3. 主要機能

### 3.1 認証機能
- **Apple Sign-In**: Firebase Authと統合
- **招待コード制**: 新規ユーザーは有効な招待コードが必要
- **管理者機能**: 招待コード生成・管理（`AdminInviteCodeView`）

### 3.2 3階層フォルダナビゲーション

#### 第1階層: 都道府県リスト（`PrefectureListView`）
- 都道府県ごとの写真数と場所数を表示
- ローカル + Firestore統合データ

#### 第2階層: 場所リスト（`LocationListView`）
- 都道府県内の場所と写真数を表示
- 位置情報がある場所は座標も表示

#### 第3階層: お店別写真リスト（`UnifiedPhotoListView`）
- 写真を`title`（お店名）でグループ化
- 各グループをタップで`PlacePhotosGridView`へ遷移

#### 写真グリッド表示（`PlacePhotosGridView`）
- 特定のお店の写真を2列グリッドで表示
- 写真削除時の自動リスト更新
- 最後の写真削除時に自動で画面を閉じる

### 3.3 地図表示

#### Google Maps（`GoogleMapView`）
- 全写真位置をカスタムカメラアイコンでマーキング
- ピンタップで写真詳細を表示
- 現在地・コンパス・ズーム操作対応

#### Apple Maps（`AppleMapView`）
- デバッグビルドのみ有効
- Google Maps代替として使用可能

### 3.4 写真追加フロー

#### 新規場所追加（`AddLocationView`）
- 最初の写真で新しい場所を作成
- EXIF GPSデータから自動位置判定
- 逆ジオコーディングで都道府県を自動設定

#### 既存場所に追加（`AddPhotoToLocationView`）
- 選択した場所に写真を追加

#### お店に写真追加（`AddPhotoToPlaceView`）
- 特定のお店に写真を追加（お店名は自動入力）
- 複数写真の一括選択対応
- EXIF GPS抽出・手動座標設定対応

### 3.5 写真削除と自動更新

**ダブルリフレッシュパターン:**
1. `SharedPhotoDetailView`で削除ボタン押下
2. `FirebaseManager.deletePhoto()`実行
3. `onDelete`コールバック発火
4. 親ビューが`removeSharedPhotoFromList()`で即座にUI更新
5. Firestoreから再取得して最新状態を反映
6. 詳細画面から戻る際は`refreshTrigger`で再読み込み

### 3.6 画像キャッシュ管理（`ImageCacheManager`）
- Firebase Storageからダウンロードした画像をローカルキャッシュ
- 30日以上前のキャッシュを自動削除
- 自分がアップロードした写真は**ローカル版を優先利用**

---

## 4. サービス層

### 4.1 FirebaseManager（`Services/FirebaseManager.swift`）
- Firestoreの全操作を管理するシングルトン
- 写真のページネーションクエリ（フィルタリング対応）
- 写真削除時の権限チェック（自分の写真のみ削除可能）

### 4.2 FirebaseStorageManager（`Services/FirebaseStorageManager.swift`）
- Firebase Storageへの画像アップロード
- アップロード進捗追跡
- アップロード後のFirestoreドキュメント作成

### 4.3 AuthenticationManager（`Services/AuthenticationManager.swift`）
- Firebase認証状態管理
- 管理者ロール判定
- Apple Sign-In統合

### 4.4 ImageCacheManager（`Services/ImageCacheManager.swift`）
- 画像キャッシュの保存・取得
- 古いキャッシュの自動クリーンアップ

### 4.5 InviteService（`Services/InviteService.swift`）
- 招待コードの生成・検証・管理

---

## 5. 主要画面一覧

| 画面名 | ファイル名 | 説明 |
|--------|-----------|------|
| ログイン画面 | `LoginView.swift` | Apple Sign-In認証 |
| サインアップ画面 | `SignUpView.swift` | 招待コード入力 |
| タブ画面 | `ContentView.swift` | 地図・リスト・設定タブ |
| 都道府県リスト | `PrefectureListView.swift` | 第1階層 |
| 場所リスト | `LocationListView.swift` | 第2階層 |
| 写真リスト | `UnifiedPhotoListView.swift` | 第3階層（お店別グループ） |
| 写真グリッド | `PlacePhotosGridView.swift` | お店の写真一覧 |
| Google地図 | `GoogleMapView.swift` | 写真位置マップ表示 |
| 場所追加 | `AddLocationView.swift` | 新規場所作成 |
| 写真追加（場所） | `AddPhotoToLocationView.swift` | 既存場所に追加 |
| 写真追加（お店） | `AddPhotoToPlaceView.swift` | お店に写真追加 |
| 場所編集 | `EditLocationView.swift` | 場所名・座標編集 |
| 写真アップロード | `UploadPhotoView.swift` | Firestoreへアップロード |
| 管理者：招待コード | `AdminInviteCodeView.swift` | 招待コード管理 |
| 設定（DEBUG） | `SettingsView.swift` | 地図切替・キャッシュ確認 |
| 診断（DEBUG） | `FirestoreDiagnosticView.swift` | Firestore生データ確認 |

---

## 6. EXIF GPS抽出フロー

`PhotosPicker`で選択された写真の処理:

1. `loadTransferable(type: Data.self)`で画像データを取得
2. `CGImageSourceCreateWithData()`でEXIFメタデータにアクセス
3. `kCGImagePropertyGPSDictionary`からGPS座標を抽出
4. `kCGImagePropertyExifDateTimeOriginal`から撮影日時を抽出
5. 半球参照（N/S, E/W）を考慮して正負を決定

参考実装: `AddPhotoToPlaceView.swift:225-310`

---

## 7. Firebase セキュリティルール

### 7.1 Firestore Rules（`firestore.rules`）
- 写真は**ユーザースコープ**: ユーザーは自分の写真のみ削除可能
- `userId`フィールドは書き込み時に検証
- 場所/都道府県フィールドはインデックス化（クエリ最適化）

### 7.2 Storage Rules（`storage.rules`）
- 写真は`/photos/{userId}/{photoId}.jpg`に保存
- ユーザーは自分のフォルダにのみアップロード可能
- ユーザーは自分の写真のみ削除可能

---

## 8. 権限

- **位置情報**: `NSLocationWhenInUseUsageDescription`（使用中のみ許可）
- **フォトライブラリ**: `NSPhotoLibraryUsageDescription`
- **Google Maps API Key**: `Info.plist`の`GMSApiKey`に設定

---

## 9. ビルドとセットアップ

### 9.1 必須環境
- Xcode 15+
- iOS 17.0+
- Google Maps API Key
- Firebase プロジェクト設定

### 9.2 ビルドコマンド

```bash
# シミュレータビルド
xcodebuild -scheme MatchSpotter -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build

# クリーンビルド
xcodebuild -scheme MatchSpotter -sdk iphonesimulator clean build

# テスト実行
xcodebuild -scheme MatchSpotter -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' test

# Xcodeで開く
open MatchSpotter.xcodeproj
```

### 9.3 必須設定ファイル
- `ios/MatchSpotter/GoogleService-Info.plist`: Firebase設定
- `ios/MatchSpotter/Info.plist`: Google Maps API Key (`GMSApiKey`)

---

## 10. デバッグ機能（DEBUG ビルドのみ）

### 10.1 設定画面（`SettingsView`）
- Google Maps / Apple Maps 切り替え
- 画像キャッシュサイズ確認
- ログアウト

### 10.2 Firestore診断画面（`FirestoreDiagnosticView`）
- Firestore生データの閲覧
- クエリデバッグ

### 10.3 アクセス方法
設定タブ経由（DEBUG ビルドでのみ表示）

---

## 11. パフォーマンス最適化

### 11.1 画像キャッシュ戦略
- 自分がアップロードした写真は**ローカル版を優先**（Storage料金削減）
- Firebase Storage画像は初回ダウンロード後にキャッシュ
- 30日以上前のキャッシュは自動削除

### 11.2 Firestore永続化
- `isPersistenceEnabled = true`でオフライン対応強化
- ローカルキャッシュによる高速読み込み

### 11.3 ページネーション
- Firestore写真クエリは20件ずつページング
- 無限スクロール対応

---

## 12. Gitワークフロー

### 12.1 ブランチ構造
- `main`: 本番リリース
- `develop`: 開発用メインブランチ
- `release/*`: リリース候補ブランチ
- 機能ブランチはPR経由で`develop`または`release/*`にマージ

### 12.2 マージ戦略
このプロジェクトでは**rebaseではなくmerge**を使用:

```bash
# ローカル変更をコミット
git add .
git commit -m "Description"

# マージでプル
git pull origin <branch> --no-rebase

# 競合解決後
git add .
git commit -m "Merge remote changes"
```

---

## 13. テスト

### 13.1 テストターゲット
`MatchSpotterTests/`
- モデルとヘルパーのユニットテスト
- Firebase操作の統合テスト（テスト設定が必要）

### 13.2 手動テストチェックリスト
- [ ] GPSデータあり/なしでの写真追加
- [ ] 写真削除とリスト自動更新
- [ ] マップピン配置（GPSからの自動 + 手動調整）
- [ ] Firestore同期（アップロード、ダウンロード、重複排除）
- [ ] 認証フロー（ログイン、ログアウト、招待コード）
- [ ] 管理者機能（招待コード生成）

---

## 14. 今後の拡張予定

- Android版の実装（Jetpack Compose + Room + Google Maps SDK）
- いいね機能の実装
- ユーザー間写真共有機能の拡張
- コメント機能
- 写真検索・フィルタリング機能の強化

---

## 15. バンドル識別子

`com.ThousandHorse.MatchSpotter.MatchSpotter`

---

## 16. 参考ドキュメント

- プロジェクト概要: `README.md`
- iOS詳細: `ios/README_iOS.md`
- Claude Code向けガイダンス: `CLAUDE.md`
