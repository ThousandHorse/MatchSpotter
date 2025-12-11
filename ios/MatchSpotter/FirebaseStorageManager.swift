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

/// Firebase Storageを使った画像アップロード管理クラス
@MainActor
class FirebaseStorageManager: ObservableObject {
    static let shared = FirebaseStorageManager()

    @Published var uploadProgress: Double = 0.0
    @Published var isUploading = false
    @Published var uploadError: String?

    private let storage = Storage.storage()
    private let db = FirebaseConfig.shared.db

    private init() {
        // Storage 初期化確認
        print("🔧 FirebaseStorageManager 初期化")
        print("   バケット名: \(storage.reference().bucket)")
        print("   ルートパス: \(storage.reference().fullPath)")
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
                throw NSError(domain: "ImageCompressionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "画像の圧縮に失敗しました"])
            }

            // サムネイルを作成
            let thumbnailData = createThumbnail(from: image, maxSize: 300)

            // ファイル名を生成
            let fileName = "\(UUID().uuidString).jpg"
            let thumbnailFileName = "\(UUID().uuidString)_thumb.jpg"

            // Storageにアップロード
            let imageURL = try await uploadImageToStorage(data: compressedData, fileName: fileName, path: "photos")
            let thumbnailURL = try await uploadImageToStorage(data: thumbnailData, fileName: thumbnailFileName, path: "thumbnails")

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

            print("💾 Firestoreに写真情報を保存開始")
            print("   タイトル: \(title)")
            print("   エリア: \(prefectureName ?? "なし")")
            print("   場所: \(locationName ?? "なし")")

            let docRef = try db.collection("sharedPhotos").addDocument(from: photo)
            var savedPhoto = photo
            savedPhoto.id = docRef.documentID

            print("✅ Firestore保存成功: ドキュメントID = \(docRef.documentID)")

            isUploading = false
            uploadProgress = 1.0

            return savedPhoto
        } catch {
            print("❌ アップロードエラー: \(error)")
            print("   エラー詳細: \(error.localizedDescription)")
            isUploading = false
            uploadError = error.localizedDescription
            throw error
        }
    }

    /// 画像をStorageにアップロード
    private func uploadImageToStorage(data: Data, fileName: String, path: String) async throws -> String {
        let storageRef = storage.reference().child("\(path)/\(fileName)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        print("📤 Storage アップロード開始")
        print("   パス: \(path)/\(fileName)")
        print("   バケット: \(storage.reference().bucket)")
        print("   データサイズ: \(data.count) bytes")
        print("   完全パス: \(storageRef.fullPath)")

        do {
            // putDataAsyncではなくputDataを使用
            let uploadTask = try await storageRef.putData(data, metadata: metadata)
            print("✅ Storage アップロード成功")
            print("   メタデータ: \(uploadTask)")

            // ダウンロードURL取得（リトライ機能付き）
            var downloadURL: URL?
            var retryCount = 0
            let maxRetries = 3

            while downloadURL == nil && retryCount < maxRetries {
                do {
                    downloadURL = try await storageRef.downloadURL()
                    print("✅ ダウンロードURL取得成功: \(downloadURL!.absoluteString)")
                } catch {
                    retryCount += 1
                    print("⚠️ ダウンロードURL取得失敗（試行\(retryCount)/\(maxRetries)）: \(error.localizedDescription)")

                    if retryCount < maxRetries {
                        // 指数バックオフで待機（0.5秒、1秒、2秒）
                        let waitTime = 0.5 * pow(2.0, Double(retryCount - 1))
                        print("   \(waitTime)秒待機してリトライします...")
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
            print("❌ Storage アップロードエラー詳細:")
            print("   エラー: \(error)")
            print("   ローカライズ: \(error.localizedDescription)")
            if let storageError = error as NSError? {
                print("   ドメイン: \(storageError.domain)")
                print("   コード: \(storageError.code)")
                print("   UserInfo: \(storageError.userInfo)")
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
}
