//
//  PhotoSpot.swift
//  MatchSpotter
//
//  Created by 千馬拓磨 on 2025/10/27.
//

import Foundation
import SwiftData
import CoreLocation

/// 都道府県フォルダモデル（第1階層）
@Model
final class Prefecture {
    var name: String
    var createdAt: Date

    // 子の場所フォルダ（削除時はカスケード削除）
    @Relationship(deleteRule: .cascade, inverse: \Location.prefecture)
    var locations: [Location] = []

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }

    // 全写真数
    var totalPhotoCount: Int {
        locations.reduce(0) { $0 + $1.totalPhotoCount }
    }

    // 場所数
    var locationCount: Int {
        locations.count
    }
}

/// 場所フォルダモデル（第2階層）
@Model
final class Location {
    var name: String
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date

    // 親の都道府県フォルダ
    var prefecture: Prefecture?

    // 関連する写真データ（削除時はカスケード削除）
    @Relationship(deleteRule: .cascade, inverse: \PhotoData.location)
    var photos: [PhotoData] = []

    init(name: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = Date()
    }

    // CoreLocation用の座標を取得（座標がある場合のみ）
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude = latitude, let longitude = longitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // 全写真数
    var totalPhotoCount: Int {
        photos.count
    }
}

/// 写真データモデル（第3階層）
@Model
final class PhotoData {
    var imageData: Data
    var title: String?
    var caption: String?
    var takenAt: Date
    var latitude: Double?
    var longitude: Double?
    var location: Location?
    var firestoreId: String? // Firestoreにアップロード済みの場合、ドキュメントIDを保存

    init(imageData: Data, title: String? = nil, caption: String? = nil, takenAt: Date = Date(), latitude: Double? = nil, longitude: Double? = nil, firestoreId: String? = nil) {
        self.imageData = imageData
        self.title = title
        self.caption = caption
        self.takenAt = takenAt
        self.latitude = latitude
        self.longitude = longitude
        self.firestoreId = firestoreId
    }
}