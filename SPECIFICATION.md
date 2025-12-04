# MatchSpotter 仕様書まとめ

本書は、写真撮影スポット管理アプリ **MatchSpotter** の現行仕様を簡潔に把握するためのサマリーです。iOS版の実装済み仕様を中心に、将来的なAndroid版の方針も含めています。

## 1. プロダクト概要
- **目的**: 写真のEXIF情報から撮影位置を自動抽出し、スポットとして地図やリストで整理できるようにする。
- **プラットフォーム**: iOS（実装済み）、Android（開発予定）。
- **対象OS**: iOS 17.0+ / Android 8.0+（予定）。
- **主要技術**: iOSは SwiftUI + SwiftData + Google Maps SDK、Androidは Jetpack Compose + Room（予定）。

## 2. 想定ユーザー体験
1. アプリを起動すると「地図」「リスト」のタブが表示される。
2. 右上の「+」から写真を選択すると、EXIFのGPS情報を用いて撮影場所が自動判定される。
3. 近隣施設候補が提示され、ユーザーは任意の名称でスポットを保存できる。
4. 保存済みスポットは地図上のピンまたはリストから参照・編集・削除できる。

## 3. 主要機能要件
- **写真スポット登録**: 写真選択、EXIFからGPS抽出、逆ジオコーディング、近隣施設検索、現在地からの手動追加。
- **地図表示**: Google Maps上にピン表示、カスタムカメラアイコン、ピン選択で詳細表示、現在地・コンパス・ズーム操作。
- **リスト表示**: サムネイル付き一覧、スワイプで編集/削除、タップで詳細。
- **スポット管理**: 名称編集、写真追加/削除、スポット削除（関連写真も一括削除）。
- **詳細表示**: グリッド写真、フルスクリーンビューア、キャプション・撮影日時表示。

## 4. 非機能要件
- **UX**: 最小タップ数でスポット登録完了（写真選択後は位置が自動入力）。
- **オフライン耐性**: ローカル永続化（SwiftData）により、接続が不安定でも閲覧・編集が可能。
- **パフォーマンス**: 地図・リストの表示はローカルキャッシュ済みデータを優先。重い処理はバックグラウンドスレッドで実施。
- **セキュリティ/プライバシー**: 位置情報・写真ライブラリ権限の利用目的を明示し、外部送信は行わない（現行仕様ではクラウド未接続）。

## 5. データモデル（共通方針）
- **PhotoSpot**: `name`, `latitude`, `longitude`, `createdAt`, `photos[PhotoData]`（1対多、カスケード削除）。
- **PhotoData**: `imageData`, `caption`, `takenAt`（撮影日時）。
- iOSでは SwiftData の `@Model` と `@Relationship(deleteRule: .cascade)` を利用。Android版は Room で同等のスキーマを予定。

## 6. 主要画面/フロー
- **タブ構成**: `ContentView`で「地図」「リスト」を切り替え。
- **地図画面**: `GoogleMapView`でスポットピン表示、タップで`PhotoSpotDetailView`へ遷移。
- **リスト画面**: `PhotoSpotListView`で並び替え・スワイプ操作、詳細遷移。
- **追加/編集フロー**: `AddPhotoSpotView`で写真選択→EXIF解析→逆ジオコーディング→施設候補提示→保存。`EditPhotoSpotView`で名称変更や写真追加。

## 7. 外部サービス・権限
- **Google Maps SDK**: iOS版は v10.4.0 をSPM経由で利用。`Info.plist`に`GMSApiKey`を設定。
- **位置情報権限**: `NSLocationWhenInUseUsageDescription`。
- **写真ライブラリ権限**: `NSPhotoLibraryUsageDescription`。
- **近隣検索**: MapKitの`MKLocalSearch`を使用し、100m圏内の施設候補を取得（iOS）。

## 8. セットアップ要約（iOS）
1. Xcode 15+ / iOS 17+ 環境を用意。
2. Google Cloud ConsoleでMaps SDKを有効化し、API Keyを取得。
3. `ios/MatchSpotter/Info.plist` の `GMSApiKey` にキーを設定。
4. `ios/MatchSpotter.xcodeproj` を開き、ビルドして実行。

## 9. 今後の拡張
- Android版の実装（Compose + Room + Google Maps SDK）。
- Firebase/Supabase等を用いたクラウド同期とデバイス間共有。
- アカウント管理・写真共有機能の追加。

## 10. 付録: 参考ファイル
- プロジェクト概要: `README.md`
- iOS詳細: `ios/README_iOS.md`
- Android計画: `android/README_Android.md`（予定）
