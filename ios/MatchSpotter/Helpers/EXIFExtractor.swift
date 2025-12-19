//
//  EXIFExtractor.swift
//  MatchSpotter
//
//  EXIF情報抽出のユーティリティ
//

import Foundation
import CoreLocation
import ImageIO
import OSLog

/// EXIF情報抽出ユーティリティ
struct EXIFExtractor {
    private static let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "EXIFExtractor")

    /// 画像データから位置情報を抽出
    /// - Parameter imageData: 画像データ
    /// - Returns: 位置情報（GPSメタデータがない場合はnil）
    static func extractLocation(from imageData: Data) -> CLLocation? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let gpsInfo = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            logger.debug("📍 GPS情報が見つかりません")
            return nil
        }

        guard let latitude = gpsInfo[kCGImagePropertyGPSLatitude as String] as? Double,
              let longitude = gpsInfo[kCGImagePropertyGPSLongitude as String] as? Double,
              let latitudeRef = gpsInfo[kCGImagePropertyGPSLatitudeRef as String] as? String,
              let longitudeRef = gpsInfo[kCGImagePropertyGPSLongitudeRef as String] as? String else {
            logger.debug("📍 GPS座標の取得に失敗")
            return nil
        }

        // 緯度・経度の正負を判定（N/S, E/W）
        let finalLatitude = latitudeRef == "S" ? -latitude : latitude
        let finalLongitude = longitudeRef == "W" ? -longitude : longitude

        logger.debug("📍 GPS情報を取得: (\(finalLatitude), \(finalLongitude))")
        return CLLocation(latitude: finalLatitude, longitude: finalLongitude)
    }

    /// 画像データから撮影日時を抽出
    /// - Parameter imageData: 画像データ
    /// - Returns: 撮影日時（EXIFメタデータがない場合はnil）
    static func extractDate(from imageData: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            logger.debug("📅 EXIFメタデータが見つかりません")
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        // 現在のタイムゾーンを使用。将来的にはEXIFのオフセット情報（kCGImagePropertyExifDateTimeOriginal）を考慮する改修も検討になります。
        dateFormatter.timeZone = TimeZone.current

        // EXIFデータから撮影日時を取得
        if let exifInfo = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateTimeOriginal = exifInfo[kCGImagePropertyExifDateTimeOriginal as String] as? String,
           let date = dateFormatter.date(from: dateTimeOriginal) {
            logger.debug("📅 EXIF撮影日時を取得: \(dateTimeOriginal) -> \(date)")
            return date
        }

        // TIFFデータから撮影日時を取得（代替）
        if let tiffInfo = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
           let dateTime = tiffInfo[kCGImagePropertyTIFFDateTime as String] as? String,
           let date = dateFormatter.date(from: dateTime) {
            logger.debug("📅 TIFF撮影日時を取得: \(dateTime) -> \(date)")
            return date
        }

        logger.debug("📅 撮影日時情報が見つかりません（EXIFなし）")
        return nil
    }
}
