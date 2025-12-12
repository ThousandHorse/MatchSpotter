import {onDocumentCreated, onDocumentDeleted} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

/**
 * エリアサマリー情報の型定義
 */
interface PrefectureSummary {
  prefectureName: string;
  photoCount: number;
  firstPhotoUploadedAt: admin.firestore.Timestamp;
  lastPhotoUploadedAt: admin.firestore.Timestamp;
  lastUpdatedAt: admin.firestore.Timestamp;
}

/**
 * 共有写真の型定義
 */
interface SharedPhoto {
  prefectureName?: string;
  uploadedAt: admin.firestore.Timestamp;
}

/**
 * 写真が追加されたときにエリアサマリーを更新
 */
export const onPhotoCreated = onDocumentCreated(
  {
    document: "sharedPhotos/{photoId}",
    region: "asia-northeast1", // Firestoreと同じリージョン（東京）
  },
  async (event) => {
    const photo = event.data?.data() as SharedPhoto;
    if (!photo) {
      console.log("⚠️ 写真データが見つかりません");
      return;
    }

    if (!photo.prefectureName) {
      console.log("⚠️ エリア名がnullのため、サマリー更新をスキップします");
      return;
    }

    const prefectureName = photo.prefectureName;
    const summaryRef = db.collection("prefecturesSummary")
      .doc(prefectureName);

    try {
      await db.runTransaction(async (transaction) => {
        const summaryDoc = await transaction.get(summaryRef);

        if (!summaryDoc.exists) {
          // 新しいエリアの場合：サマリーを作成
          const newSummary: PrefectureSummary = {
            prefectureName: prefectureName,
            photoCount: 1,
            firstPhotoUploadedAt: photo.uploadedAt,
            lastPhotoUploadedAt: photo.uploadedAt,
            lastUpdatedAt: admin.firestore.Timestamp.now(),
          };
          transaction.set(summaryRef, newSummary);
          console.log(
            `✅ 新規エリアサマリー作成: ${prefectureName} (1枚)`
          );
        } else {
          // 既存エリアの場合：写真数を増やし、日時を更新
          const summary = summaryDoc.data() as PrefectureSummary;
          const updatedSummary: Partial<PrefectureSummary> = {
            photoCount: summary.photoCount + 1,
            lastPhotoUploadedAt: photo.uploadedAt,
            lastUpdatedAt: admin.firestore.Timestamp.now(),
          };

          // firstPhotoUploadedAtは、より古い方を保持
          if (photo.uploadedAt.toMillis() <
              summary.firstPhotoUploadedAt.toMillis()) {
            updatedSummary.firstPhotoUploadedAt = photo.uploadedAt;
          }

          transaction.update(summaryRef, updatedSummary);
          console.log(
            `✅ エリアサマリー更新: ${prefectureName} ` +
            `(${summary.photoCount} → ${summary.photoCount + 1}枚)`
          );
        }
      });
    } catch (error) {
      console.error("❌ エリアサマリー更新エラー:", error);
      throw error;
    }
  });

/**
 * 写真が削除されたときにエリアサマリーを更新
 */
export const onPhotoDeleted = onDocumentDeleted(
  {
    document: "sharedPhotos/{photoId}",
    region: "asia-northeast1", // Firestoreと同じリージョン（東京）
  },
  async (event) => {
    const photo = event.data?.data() as SharedPhoto;
    if (!photo) {
      console.log("⚠️ 写真データが見つかりません");
      return;
    }

    if (!photo.prefectureName) {
      console.log("⚠️ エリア名がnullのため、サマリー更新をスキップします");
      return;
    }

    const prefectureName = photo.prefectureName;
    const summaryRef = db.collection("prefecturesSummary")
      .doc(prefectureName);

    try {
      await db.runTransaction(async (transaction) => {
        const summaryDoc = await transaction.get(summaryRef);

        if (!summaryDoc.exists) {
          console.log(
            `⚠️ エリアサマリーが存在しません: ${prefectureName}`
          );
          return;
        }

        const summary = summaryDoc.data() as PrefectureSummary;
        const newPhotoCount = Math.max(0, summary.photoCount - 1);

        if (newPhotoCount === 0) {
          // 写真が0枚になった場合：サマリーを削除
          transaction.delete(summaryRef);
          console.log(`🗑️ エリアサマリー削除: ${prefectureName} (0枚)`);
        } else {
          // まだ写真が残っている場合：カウントを減らす
          // 注: 日時の再計算は行わない（コスト削減のため）
          // 必要であれば、定期的な再計算バッチジョブを別途実装
          transaction.update(summaryRef, {
            photoCount: newPhotoCount,
            lastUpdatedAt: admin.firestore.Timestamp.now(),
          });
          console.log(
            `✅ エリアサマリー更新: ${prefectureName} ` +
            `(${summary.photoCount} → ${newPhotoCount}枚)`
          );
        }
      });
    } catch (error) {
      console.error("❌ エリアサマリー更新エラー:", error);
      throw error;
    }
  });

/**
 * 全エリアサマリーを再計算（メンテナンス用）
 * 手動実行: firebase functions:call rebuildPrefecturesSummary
 */
export const rebuildPrefecturesSummary = onCall(
  {
    region: "asia-northeast1", // Firestoreと同じリージョン（東京）
  },
  async (request) => {
    // 認証チェック（オプション）
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "認証が必要です"
      );
    }

    console.log("🔧 全エリアサマリー再計算開始");

    try {
      // 既存のサマリーを全削除
      const existingSummaries = await db.collection("prefecturesSummary")
        .get();
      const batch1 = db.batch();
      existingSummaries.docs.forEach((doc) => {
        batch1.delete(doc.ref);
      });
      await batch1.commit();
      console.log(`🗑️ 既存サマリー削除: ${existingSummaries.size}件`);

      // 全写真を取得してエリアごとに集計
      const allPhotos = await db.collection("sharedPhotos").get();
      const summaryMap = new Map<string, {
        count: number;
        firstUpload: admin.firestore.Timestamp;
        lastUpload: admin.firestore.Timestamp;
      }>();

      allPhotos.docs.forEach((doc) => {
        const photo = doc.data() as SharedPhoto;
        if (!photo.prefectureName) return;

        const existing = summaryMap.get(photo.prefectureName);
        if (!existing) {
          summaryMap.set(photo.prefectureName, {
            count: 1,
            firstUpload: photo.uploadedAt,
            lastUpload: photo.uploadedAt,
          });
        } else {
          existing.count += 1;
          if (photo.uploadedAt.toMillis() <
              existing.firstUpload.toMillis()) {
            existing.firstUpload = photo.uploadedAt;
          }
          if (photo.uploadedAt.toMillis() >
              existing.lastUpload.toMillis()) {
            existing.lastUpload = photo.uploadedAt;
          }
        }
      });

      // 新しいサマリーを作成
      const batch2 = db.batch();
      summaryMap.forEach((data, prefectureName) => {
        const summaryRef = db.collection("prefecturesSummary")
          .doc(prefectureName);
        const summary: PrefectureSummary = {
          prefectureName: prefectureName,
          photoCount: data.count,
          firstPhotoUploadedAt: data.firstUpload,
          lastPhotoUploadedAt: data.lastUpload,
          lastUpdatedAt: admin.firestore.Timestamp.now(),
        };
        batch2.set(summaryRef, summary);
      });
      await batch2.commit();

      console.log(`✅ 再計算完了: ${summaryMap.size}個のエリア`);
      return {
        success: true,
        prefectureCount: summaryMap.size,
        photoCount: allPhotos.size,
      };
    } catch (error) {
      console.error("❌ 再計算エラー:", error);
      throw new HttpsError("internal", "再計算に失敗しました");
    }
  });
