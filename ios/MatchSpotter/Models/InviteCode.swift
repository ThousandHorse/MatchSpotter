//
//  InviteCode.swift
//  MatchSpotter
//
//  招待コードのFirestoreモデル
//

import Foundation
import FirebaseFirestore

struct InviteCode: Codable, Identifiable {
    @DocumentID var id: String?
    let code: String
    var isUsed: Bool
    var usedBy: String?
    let createdBy: String
    let expiresAt: Date?
    let createdAt: Date

    // 表示用プロパティ（Firestoreには保存されない）
    var usedByDisplayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case isUsed
        case usedBy
        case createdBy
        case expiresAt
        case createdAt
        // usedByDisplayName は含めない（Firestoreに保存しない）
    }

    // Firestoreから読み込む用
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        code = try container.decode(String.self, forKey: .code)
        isUsed = try container.decode(Bool.self, forKey: .isUsed)
        usedBy = try container.decodeIfPresent(String.self, forKey: .usedBy)
        createdBy = try container.decode(String.self, forKey: .createdBy)

        // TimestampをDateに変換
        if let timestamp = try? container.decode(Timestamp.self, forKey: .expiresAt) {
            expiresAt = timestamp.dateValue()
        } else {
            expiresAt = nil
        }

        let createdAtTimestamp = try container.decode(Timestamp.self, forKey: .createdAt)
        createdAt = createdAtTimestamp.dateValue()

        // 表示用プロパティは初期化時は nil
        usedByDisplayName = nil
    }

    // Firestoreに書き込む用
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(code, forKey: .code)
        try container.encode(isUsed, forKey: .isUsed)
        try container.encodeIfPresent(usedBy, forKey: .usedBy)
        try container.encode(createdBy, forKey: .createdBy)

        if let expiresAt = expiresAt {
            try container.encode(Timestamp(date: expiresAt), forKey: .expiresAt)
        }

        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
    }

    // 初期化用
    init(code: String, createdBy: String, expiresAt: Date? = nil) {
        self.id = nil
        self.code = code
        self.isUsed = false
        self.usedBy = nil
        self.createdBy = createdBy
        self.expiresAt = expiresAt
        self.createdAt = Date()
        self.usedByDisplayName = nil
    }

    // 有効期限チェック
    var isExpired: Bool {
        guard let expiresAt = expiresAt else {
            return false // 有効期限がない場合は期限切れでない
        }
        return Date() > expiresAt
    }
}
