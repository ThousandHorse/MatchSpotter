//
//  PhotoSpot.swift
//  MatchSpotter
//
//  Created by 千馬拓磨 on 2025/10/27.
//

import Foundation
import SwiftData
import CoreLocation

/// 撮影スポットモデル
@Model
final class PhotoSpot {
    var name: String
    var latitude: Double
    var longitude: Double
    var createdAt: Date

    // 関連する写真データ（削除時はカスケード削除）
    @Relationship(deleteRule: .cascade, inverse: \PhotoData.photoSpot)
    var photos: [PhotoData] = []
    

    init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = Date()
    }

    // CoreLocation用の座標を取得
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// 写真データモデル
@Model
final class PhotoData {
    var imageData: Data
    var caption: String?
    var takenAt: Date
    var photoSpot: PhotoSpot?

    init(imageData: Data, caption: String? = nil, takenAt: Date = Date()) {
        self.imageData = imageData
        self.caption = caption
        self.takenAt = takenAt
    }
}
