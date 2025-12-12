//
//  FirebaseStorageManager.swift
//  MatchSpotter
//
//  Created by Claude
//

import Foundation
import Combine
import FirebaseStorage
import FirebaseFirestore
import UIKit
import OSLog

/// Firebase Storage操作のエラー型
enum FirebaseStorageError: LocalizedError {
    case imageCompressionFailed
    case uploadFailed
    case downloadURLFailed

    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "画像の圧縮に失敗しました"
        case .uploadFailed:
            return "画像のアップロードに失敗しました"
        case .downloadURLFailed:
            return "ダウンロードURLの取得に失敗しました"
        }
    }
}

/// Firebase Storageを使った画像アップロード管理クラス
@MainActor
class FirebaseStorageManager: ObservableObject {
    static let shared = FirebaseStorageManager()

    @Published var uploadProgress: Double = 0.0
    @Published var isUploading = false
    @Published var uploadError: String?

    private let storage = Storage.storage()
    private let db = FirebaseConfig.shared.db
    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "FirebaseStorageManager")

    private init() {
        // Storage 初期化確認
        logger.debug("🔧 FirebaseStorageManager 初期化")
        logger.debug("   バケット名: \(self.storage.reference().bucket)")
        logger.debug("   ルートパス: \(self.storage.reference().fullPath)")
    }

    /// 画像をFirebase Storageにアップロードし、Firestoreに写真情報を保存
    func uploadPhoto(
        imageData: Data,
        title: String,
        caption: String?,
        latitude: Double?,
        longitude: Double?,
        locationName: String?,
        prefectureName: String?,
        userId: String,
        userName: String?,
        takenAt: Date
    ) async throws -> SharedPhoto {
        isUploading = true
        uploadProgress = 0.0
        uploadError = nil

        do {
            // 画像を圧縮
            guard let image = UIImage(data: imageData),
                  let compressedData = compressImage(image, maxSizeKB: 1024) else {
                throw FirebaseStorageError.imageCompressionFailed
            }

            // サムネイルを作成
            let thumbnailData = createThumbnail(from: image, maxSize: 300)

            // ファイル名を生成
            let fileName = "\(UUID().uuidString).jpg"
            let thumbnailFileName = "\(UUID().uuidString)_thumb.jpg"

            // Storageにアップロード（ユーザーID別のパス構造） - 並列実行で短縮
            async let imageURLResult = uploadImageToStorage(data: compressedData, fileName: fileName, path: "photos", userId: userId)
            async let thumbnailURLResult = uploadImageToStorage(data: thumbnailData, fileName: thumbnailFileName, path: "thumbnails", userId: userId)
            let (imageURL, thumbnailURL) = try await (imageURLResult, thumbnailURLResult)

            // Firestoreに写真情報を保存
            let photo = SharedPhoto(
                imageURL: imageURL,
                thumbnailURL: thumbnailURL,
                title: title,
                caption: caption,
                latitude: latitude,
                longitude: longitude,
                locationName: locationName,
                prefectureName: prefectureName,
                userId: userId,
                userName: userName,
                takenAt: takenAt
            )

            logger.debug("💾 Firestoreに写真情報を保存開始")
            logger.debug("   タイトル: \(title)")
            logger.debug("   エリア: \(prefectureName ?? "なし")")
            logger.debug("   場所: \(locationName ?? "なし")")

            let docRef = try db.collection("sharedPhotos").addDocument(from: photo)
            var savedPhoto = photo
            savedPhoto.id = docRef.documentID

            logger.info("✅ Firestore保存成功: ドキュメントID = \(docRef.documentID)")

            isUploading = false
            uploadProgress = 1.0

            return savedPhoto
        } catch {
            logger.error("❌ アップロードエラー: \(error.localizedDescription)")
            isUploading = false
            throw error
        }
    }

    /// 画像をStorageにアップロード
    private func uploadImageToStorage(data: Data, fileName: String, path: String, userId: String) async throws -> String {
        let storageRef = storage.reference().child("\(path)/\(userId)/\(fileName)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        logger.debug("📤 Storage アップロード開始")
        logger.debug("   パス: \(path)/\(userId)/\(fileName)")
        logger.debug("   バケット: \(self.storage.reference().bucket)")
        logger.debug("   データサイズ: \(data.count) bytes")
        logger.debug("   完全パス: \(storageRef.fullPath)")

        do {
            // putDataAsyncではなくputDataを使用
            let uploadTask = try await storageRef.putData(data, metadata: metadata)
            logger.info("✅ Storage アップロード成功")
            logger.debug("   メタデータ: \(String(describing: uploadTask))")

            // ダウンロードURL取得（リトライ機能付き）
            var downloadURL: URL?
            var retryCount = 0
            let maxRetries = 3

            while downloadURL == nil && retryCount < maxRetries {
                do {
                    downloadURL = try await storageRef.downloadURL()
                    logger.info("✅ ダウンロードURL取得成功: \(downloadURL!.absoluteString)")
                } catch {
                    retryCount += 1
                    logger.warning("⚠️ ダウンロードURL取得失敗（試行\(retryCount)/\(maxRetries)）: \(error.localizedDescription)")

                    if retryCount < maxRetries {
                        // 指数バックオフ + ジッター（0.5秒、1秒、2秒 に ±最大0.5秒の揺らぎ）
                        let base = 0.5 * pow(2.0, Double(retryCount - 1))
                        let jitter = Double.random(in: 0...0.5)
                        let waitTime = base + jitter
                        logger.debug("   \(waitTime)秒待機してリトライします...")
                        try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                    } else {
                        throw error
                    }
                }
            }

            guard let finalURL = downloadURL else {
                throw NSError(
                    domain: "FirebaseStorageManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "ダウンロードURLの取得に失敗しました"]
                )
            }

            return finalURL.absoluteString
        } catch {
            logger.error("❌ Storage アップロードエラー詳細:")
            logger.error("   エラー: \(error.localizedDescription)")
            if let storageError = error as NSError? {
                logger.error("   ドメイン: \(storageError.domain)")
                logger.error("   コード: \(storageError.code)")
                logger.error("   UserInfo: \(String(describing: storageError.userInfo))")
            }
            throw error
        }
    }

    /// 画像を圧縮
    private func compressImage(_ image: UIImage, maxSizeKB: Int) -> Data? {
        var compression: CGFloat = 1.0
        var imageData = image.jpegData(compressionQuality: compression)

        while let data = imageData, data.count > maxSizeKB * 1024 && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }

        return imageData
    }

    /// サムネイル画像を作成
    private func createThumbnail(from image: UIImage, maxSize: CGFloat) -> Data {
        let size = image.size
        let aspectRatio = size.width / size.height
        var thumbnailSize: CGSize

        if aspectRatio > 1 {
            thumbnailSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            thumbnailSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }

        UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return thumbnail?.jpegData(compressionQuality: 0.8) ?? Data()
    }

    /// Storageから画像を削除
    func deleteImage(imageURL: String) async throws {
        let storageRef = storage.reference(forURL: imageURL)
        try await storageRef.delete()
    }

    /// FirestoreドキュメントIDからストレージ上の画像を削除（孤立ファイル対策）
    func deleteOrphanedPhoto(firestoreId: String) async {
        do {
            let doc = try await db.collection("sharedPhotos").document(firestoreId).getDocument()
            guard doc.exists else { return }
            let photo = try doc.data(as: SharedPhoto.self)

            // オリジナルとサムネイルを削除
            try await deleteImage(imageURL: photo.imageURL)
            if let thumb = photo.thumbnailURL {
                try await deleteImage(imageURL: thumb)
            }
        } catch {
            logger.error("孤立ファイル削除エラー (firestoreId=\(firestoreId)): \(error.localizedDescription)")
        }
    }
}
