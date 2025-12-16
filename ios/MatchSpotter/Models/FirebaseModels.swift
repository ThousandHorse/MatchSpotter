//
//  FirebaseModels.swift
//  MatchSpotter
//
//  Created by Claude
//

import Foundation
import FirebaseFirestore

/// Firestore用のユーザーモデル
struct User: Codable, Identifiable {
    @DocumentID var id: String?
    var email: String
    var displayName: String?
    var nickname: String? // ユーザーが設定するニックネーム
    var photoURL: String?
    var createdAt: Date

    init(id: String? = nil, email: String, displayName: String? = nil, nickname: String? = nil, photoURL: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.nickname = nickname
        self.photoURL = photoURL
        self.createdAt = Date()
    }
}

/// Firestore用の共有写真モデル
struct SharedPhoto: Codable, Identifiable {
    @DocumentID var id: String?
    var imageURL: String // Firebase Storageの画像URL
    var thumbnailURL: String? // サムネイル画像URL
    var title: String
    var caption: String?
    var latitude: Double?
    var longitude: Double?
    var hasLocation: Bool // 位置情報の有無（クエリ最適化用）
    var locationName: String? // 場所の名前（例: "新宿", "渋谷"）
    var prefectureName: String? // 都道府県名
    var userId: String // アップロードしたユーザーのID
    var userName: String? // ユーザー表示名
    var takenAt: Date
    var uploadedAt: Date
    var likes: Int // いいね数
    var likedBy: [String] // いいねしたユーザーのIDリスト

    init(
        id: String? = nil,
        imageURL: String,
        thumbnailURL: String? = nil,
        title: String,
        caption: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        prefectureName: String? = nil,
        userId: String,
        userName: String? = nil,
        takenAt: Date = Date(),
        uploadedAt: Date = Date(),
        likes: Int = 0,
        likedBy: [String] = []
    ) {
        self.id = id
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.title = title
        self.caption = caption
        self.latitude = latitude
        self.longitude = longitude
        self.hasLocation = (latitude != nil && longitude != nil) // 位置情報の有無を自動判定
        self.locationName = locationName
        self.prefectureName = prefectureName
        self.userId = userId
        self.userName = userName
        self.takenAt = takenAt
        self.uploadedAt = uploadedAt
        self.likes = likes
        self.likedBy = likedBy
    }
}

/// 写真のフィルタリング条件
enum PhotoFilter: Equatable {
    case all // 全ての写真
    case myPhotos // 自分の写真のみ
    case prefecture(String) // 特定の都道府県
    case location(String) // 特定の場所
    case recent // 最近の写真
}
