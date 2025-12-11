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

    private init() {}

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

            let docRef = try db.collection("sharedPhotos").addDocument(from: photo)
            var savedPhoto = photo
            savedPhoto.id = docRef.documentID

            isUploading = false
            uploadProgress = 1.0

            return savedPhoto
        } catch {
            isUploading = false
            throw error
        }
    }

    /// 画像をStorageにアップロード
    private func uploadImageToStorage(data: Data, fileName: String, path: String) async throws -> String {
        let storageRef = storage.reference().child("\(path)/\(fileName)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        // putDataAsyncではなくputDataを使用
        _ = try await storageRef.putData(data, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()

        return downloadURL.absoluteString
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
