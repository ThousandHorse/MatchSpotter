//
//  PrefectureSummary.swift
//  MatchSpotter
//
//  Created by Claude
//

import Foundation
import FirebaseFirestore

/// エリアのサマリー情報（Firestoreの prefecturesSummary コレクション用）
struct PrefectureSummary: Identifiable, Codable {
    @DocumentID var id: String?

    /// エリア名（ドキュメントIDとしても使用）
    let prefectureName: String

    /// このエリアの写真数
    var photoCount: Int

    /// 最初の写真が投稿された日時
    var firstPhotoUploadedAt: Date

    /// 最後の写真が投稿された日時
    var lastPhotoUploadedAt: Date

    /// 最後に更新された日時
    var lastUpdatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case prefectureName
        case photoCount
        case firstPhotoUploadedAt
        case lastPhotoUploadedAt
        case lastUpdatedAt
    }

    init(
        id: String? = nil,
        prefectureName: String,
        photoCount: Int = 0,
        firstPhotoUploadedAt: Date = Date(),
        lastPhotoUploadedAt: Date = Date(),
        lastUpdatedAt: Date = Date()
    ) {
        self.id = id
        self.prefectureName = prefectureName
        self.photoCount = photoCount
        self.firstPhotoUploadedAt = firstPhotoUploadedAt
        self.lastPhotoUploadedAt = lastPhotoUploadedAt
        self.lastUpdatedAt = lastUpdatedAt
    }
}
