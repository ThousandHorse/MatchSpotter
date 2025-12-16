//
//  LocationHelper.swift
//  MatchSpotter
//
//  Location作成のヘルパーメソッド
//

import SwiftUI
import SwiftData
import OSLog

/// Location作成の共通ロジック
struct LocationHelper {
    private static let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "LocationHelper")

    /// PrefectureとLocationを作成または取得する
    /// - Parameters:
    ///   - prefectureName: 都道府県名
    ///   - locationName: 場所名
    ///   - latitude: 緯度（オプション）
    ///   - longitude: 経度（オプション）
    ///   - modelContext: SwiftDataのModelContext
    ///   - allPrefectures: 既存のPrefecture配列（@Queryで取得したもの）
    /// - Returns: 作成または取得したLocation（失敗時はnil）
    static func getOrCreateLocation(
        prefectureName: String,
        locationName: String,
        latitude: Double?,
        longitude: Double?,
        modelContext: ModelContext,
        allPrefectures: [Prefecture]
    ) -> Location? {
        // 既存のPrefectureを探す
        var prefecture = allPrefectures.first(where: { $0.name == prefectureName })

        // Prefectureがなければ作成
        if prefecture == nil {
            logger.debug("📝 Prefectureが見つからないため新規作成: \(prefectureName)")
            let newPrefecture = Prefecture(name: prefectureName)
            modelContext.insert(newPrefecture)

            do {
                try modelContext.save()
                logger.info("✅ Prefecture保存成功")
                prefecture = newPrefecture
            } catch {
                logger.error("❌ Prefectureの作成保存エラー: \(error.localizedDescription)")
                return nil
            }
        }

        guard let targetPrefecture = prefecture else {
            logger.error("❌ Prefecture取得失敗")
            return nil
        }

        // 新しいLocationを作成
        let newLocation = Location(
            name: locationName,
            latitude: latitude,
            longitude: longitude
        )

        // Prefectureとの関連付け
        newLocation.prefecture = targetPrefecture

        modelContext.insert(newLocation)

        do {
            try modelContext.save()
            logger.info("✅ Location保存成功: \(newLocation.name)")
            return newLocation
        } catch {
            logger.error("❌ Locationの作成保存エラー: \(error.localizedDescription)")
            return nil
        }
    }
}
