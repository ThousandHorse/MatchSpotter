//
//  UnifiedModels.swift
//  MatchSpotter
//
//  ローカルデータとFirestoreデータを統合するためのモデル
//

import Foundation
import SwiftData
import UIKit
import OSLog

/// 統合されたエリア（Prefecture）モデル
struct UnifiedPrefecture: Identifiable {
    let id: String
    let name: String
    var localPrefecture: Prefecture? // ローカルのPrefecture
    var photoCount: Int // 写真の総数（ローカル + Firestore）
    var createdAt: Date

    init(name: String, localPrefecture: Prefecture? = nil, photoCount: Int = 0, createdAt: Date = Date()) {
        self.id = name // 名前をIDとして使用（重複排除のため）
        self.name = name
        self.localPrefecture = localPrefecture
        self.photoCount = photoCount
        self.createdAt = createdAt
    }
}

/// 統合された場所（Location）モデル
struct UnifiedLocation: Identifiable {
    let id: String
    let name: String
    let prefectureName: String
    var localLocation: Location? // ローカルのLocation
    var photoCount: Int // 写真の総数（ローカル + Firestore）
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date

    init(name: String, prefectureName: String, localLocation: Location? = nil, photoCount: Int = 0, latitude: Double? = nil, longitude: Double? = nil, createdAt: Date = Date()) {
        self.id = "\(prefectureName)_\(name)" // 都道府県名+場所名をIDとして使用
        self.name = name
        self.prefectureName = prefectureName
        self.localLocation = localLocation
        self.photoCount = photoCount
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
    }
}

/// 統合された写真（Photo）モデル
enum UnifiedPhoto: Identifiable {
    case local(PhotoData)
    case shared(SharedPhoto)

    private static let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "UnifiedPhoto")

    var id: String {
        switch self {
        case .local(let photo):
            return "local_\(photo.persistentModelID.hashValue)"
        case .shared(let photo):
            return "shared_\(photo.id ?? UUID().uuidString)"
        }
    }

    var title: String? {
        switch self {
        case .local(let photo):
            return photo.title
        case .shared(let photo):
            return photo.title
        }
    }

    var caption: String? {
        switch self {
        case .local(let photo):
            return photo.caption
        case .shared(let photo):
            return photo.caption
        }
    }

    var takenAt: Date {
        switch self {
        case .local(let photo):
            return photo.takenAt
        case .shared(let photo):
            return photo.takenAt
        }
    }

    var isLocal: Bool {
        switch self {
        case .local:
            return true
        case .shared:
            return false
        }
    }

    var localPhoto: PhotoData? {
        switch self {
        case .local(let photo):
            return photo
        case .shared:
            return nil
        }
    }

    var sharedPhoto: SharedPhoto? {
        switch self {
        case .local:
            return nil
        case .shared(let photo):
            return photo
        }
    }

    /// 画像データを効率的に取得（自分がアップロードした写真はローカル版を使用してStorage料金削減）
    func getImageData(currentUserId: String?, localPhotos: [PhotoData] = []) async -> Data? {
        switch self {
        case .local(let photoData):
            // ローカル写真はそのまま返す（無料）
            return photoData.imageData

        case .shared(let sharedPhoto):
            // 自分がアップロードした写真の場合、ローカル版を探す
            if sharedPhoto.userId == currentUserId {
                let matchingLocal = localPhotos.first { $0.firestoreId == sharedPhoto.id }
                if let localPhoto = matchingLocal {
                    Self.logger.info("💾 ローカル画像を使用（Firebase Storage アクセス回避）: \(sharedPhoto.title)")
                    return localPhoto.imageData
                }
            }

            // 他のユーザーの写真はキャッシュから取得（なければダウンロード）
            let imageURL = sharedPhoto.thumbnailURL ?? sharedPhoto.imageURL

            do {
                let image = try await ImageCacheManager.shared.getImage(from: imageURL)
                return image.jpegData(compressionQuality: 0.8)
            } catch {
                Self.logger.error("❌ 画像取得エラー: \(error.localizedDescription)")
                return nil
            }
        }
    }
}
