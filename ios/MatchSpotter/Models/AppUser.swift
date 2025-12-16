//
//  AppUser.swift
//  MatchSpotter
//
//  アプリユーザーのFirestoreモデル
//

import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    let uid: String
    let email: String
    var nickname: String?
    var isAdmin: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case uid
        case email
        case nickname
        case isAdmin
        case createdAt
    }

    // Firestoreから読み込む用
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        uid = try container.decode(String.self, forKey: .uid)
        email = try container.decode(String.self, forKey: .email)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        isAdmin = try container.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false

        // TimestampをDateに変換
        let createdAtTimestamp = try container.decode(Timestamp.self, forKey: .createdAt)
        createdAt = createdAtTimestamp.dateValue()
    }

    // Firestoreに書き込む用
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(uid, forKey: .uid)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encode(isAdmin, forKey: .isAdmin)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
    }

    // 初期化用
    init(uid: String, email: String, nickname: String? = nil, isAdmin: Bool = false) {
        self.id = uid // Firestoreのドキュメント IDはuidと同じにする
        self.uid = uid
        self.email = email
        self.nickname = nickname
        self.isAdmin = isAdmin
        self.createdAt = Date()
    }
}
