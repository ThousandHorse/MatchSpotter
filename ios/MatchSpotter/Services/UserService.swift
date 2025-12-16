//
//  UserService.swift
//  MatchSpotter
//
//  Firestoreのusersコレクションを管理するサービス
//

import Foundation
import FirebaseFirestore
import OSLog

class UserService {
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "UserService")

    // MARK: - ユーザー作成

    /// Firestoreのusersコレクションにユーザーを作成
    func createUser(uid: String, email: String, nickname: String?, isAdmin: Bool = false) async throws {
        logger.debug("👤 Firestoreにユーザー作成開始: UID=\(uid), email=\(email), nickname=\(nickname ?? "なし")")

        let user = AppUser(uid: uid, email: email, nickname: nickname, isAdmin: isAdmin)

        do {
            try db.collection("users")
                .document(uid)
                .setData(from: user)
            logger.info("✅ Firestoreユーザー作成成功: UID=\(uid)")
        } catch {
            logger.error("❌ Firestoreユーザー作成失敗: UID=\(uid), エラー: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - ユーザー取得

    /// Firestoreからユーザー情報を取得
    func fetchUser(uid: String) async throws -> AppUser? {
        logger.debug("👤 ユーザー情報取得開始: UID=\(uid)")

        do {
            let document = try await db.collection("users")
                .document(uid)
                .getDocument()

            if !document.exists {
                logger.warning("⚠️ ユーザーが見つかりません: UID=\(uid) - Firestoreのusersコレクションにドキュメントが存在しません")
                return nil
            }

            let user = try document.data(as: AppUser.self)
            logger.info("✅ ユーザー情報取得成功: email=\(user.email), nickname=\(user.nickname ?? "なし")")
            return user
        } catch {
            logger.error("❌ ユーザー情報取得エラー: UID=\(uid), エラー: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - ニックネーム更新

    /// ニックネームを更新
    func updateNickname(uid: String, nickname: String) async throws {
        try await db.collection("users")
            .document(uid)
            .updateData([
                "nickname": nickname
            ])
    }
}
