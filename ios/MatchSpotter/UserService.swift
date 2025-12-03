//
//  UserService.swift
//  MatchSpotter
//
//  Firestoreのusersコレクションを管理するサービス
//

import Foundation
import FirebaseFirestore

class UserService {
    private let db = Firestore.firestore()

    // MARK: - ユーザー作成

    /// Firestoreのusersコレクションにユーザーを作成
    func createUser(uid: String, email: String, nickname: String?, isAdmin: Bool = false) async throws {
        print("👤 Firestoreにユーザー作成開始: UID=\(uid), email=\(email), nickname=\(nickname ?? "なし")")

        let user = AppUser(uid: uid, email: email, nickname: nickname, isAdmin: isAdmin)

        do {
            try db.collection("users")
                .document(uid)
                .setData(from: user)
            print("✅ Firestoreユーザー作成成功: UID=\(uid)")
        } catch {
            print("❌ Firestoreユーザー作成失敗: UID=\(uid)")
            print("   エラー詳細: \(error.localizedDescription)")
            print("   エラー: \(error)")
            throw error
        }
    }

    // MARK: - ユーザー取得

    /// Firestoreからユーザー情報を取得
    func fetchUser(uid: String) async throws -> AppUser? {
        print("👤 ユーザー情報取得開始: UID=\(uid)")

        do {
            let document = try await db.collection("users")
                .document(uid)
                .getDocument()

            if !document.exists {
                print("⚠️ ユーザーが見つかりません: UID=\(uid)")
                print("   Firestoreのusersコレクションにドキュメントが存在しません")
                return nil
            }

            let user = try document.data(as: AppUser.self)
            print("✅ ユーザー情報取得成功: email=\(user.email), nickname=\(user.nickname ?? "なし")")
            return user
        } catch {
            print("❌ ユーザー情報取得エラー: UID=\(uid)")
            print("   エラー詳細: \(error.localizedDescription)")
            print("   エラー: \(error)")
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
