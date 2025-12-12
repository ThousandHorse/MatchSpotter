//
//  ImageCacheManager.swift
//  MatchSpotter
//
//  Firebase Storageからの画像をキャッシュして通信量を削減
//

import Foundation
import UIKit
import CryptoKit
import OSLog

/// 画像キャッシュマネージャー - Firebase Storageからの画像をローカルに保存して再利用
class ImageCacheManager {
    static let shared = ImageCacheManager()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "ImageCacheManager")

    private init() {
        // キャッシュディレクトリを取得
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("FirebaseImageCache", isDirectory: true)

        // ディレクトリが存在しない場合は作成
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }

        logger.debug("📁 画像キャッシュディレクトリ: \(self.cacheDirectory.path)")
    }

    /// URLから画像を取得（キャッシュがあればキャッシュから、なければダウンロード）
    func getImage(from url: String) async throws -> UIImage {
        // キャッシュファイル名を生成（URLのハッシュ値を使用）
        let cacheFileName = url.sha256() + ".jpg"
        let cacheFileURL = cacheDirectory.appendingPathComponent(cacheFileName)

        // キャッシュが存在するか確認
        if fileManager.fileExists(atPath: cacheFileURL.path) {
            if let cachedData = try? Data(contentsOf: cacheFileURL),
               let cachedImage = UIImage(data: cachedData) {
                logger.debug("✅ キャッシュから画像取得: \(cacheFileName)")
                return cachedImage
            }
        }

        // キャッシュがない場合はダウンロード
        logger.debug("📥 画像をダウンロード: \(url)")
        guard let imageURL = URL(string: url) else {
            throw NSError(domain: "ImageCacheManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "無効なURL"])
        }

        let (data, _) = try await URLSession.shared.data(from: imageURL)

        guard let image = UIImage(data: data) else {
            throw NSError(domain: "ImageCacheManager", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "画像のデコードに失敗"])
        }

        // キャッシュに保存
        try? data.write(to: cacheFileURL)
        logger.info("💾 画像をキャッシュに保存: \(cacheFileName)")

        return image
    }

    /// キャッシュされた画像を取得（非同期、キャッシュがない場合はnil）
    func getCachedImage(from url: String) -> UIImage? {
        let cacheFileName = url.sha256() + ".jpg"
        let cacheFileURL = cacheDirectory.appendingPathComponent(cacheFileName)

        if fileManager.fileExists(atPath: cacheFileURL.path),
           let cachedData = try? Data(contentsOf: cacheFileURL),
           let cachedImage = UIImage(data: cachedData) {
            return cachedImage
        }

        return nil
    }

    /// キャッシュサイズを取得（MB単位）
    func getCacheSize() -> Double {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory,
                                                       includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize)
            }
        }

        return Double(totalSize) / 1024.0 / 1024.0 // MB
    }

    /// キャッシュをクリア
    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        logger.info("🗑️ 画像キャッシュをクリアしました")
    }

    /// 古いキャッシュを削除（30日以上前のもの）
    func clearOldCache(olderThan days: Int = 30) {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory,
                                                       includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }

        let cutoffDate = Date().addingTimeInterval(-Double(days * 24 * 60 * 60))
        var deletedCount = 0

        for case let fileURL as URL in enumerator {
            if let modificationDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               modificationDate < cutoffDate {
                try? fileManager.removeItem(at: fileURL)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            logger.info("🗑️ \(deletedCount)個の古いキャッシュを削除しました")
        }
    }
}

/// String の SHA256 ハッシュを計算する拡張
extension String {
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return self }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
