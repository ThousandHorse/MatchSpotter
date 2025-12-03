//
//  InviteService.swift
//  MatchSpotter
//
//  招待コードの検証と管理を行うサービス
//

import Foundation
import FirebaseFirestore

enum InviteError: LocalizedError {
    case codeNotFound
    case codeAlreadyUsed
    case codeExpired
    case invalidCode

    var errorDescription: String? {
        switch self {
        case .codeNotFound:
            return "招待コードが存在しません"
        case .codeAlreadyUsed:
            return "すでに使用済みの招待コードです"
        case .codeExpired:
            return "招待コードの有効期限が切れています"
        case .invalidCode:
            return "無効な招待コードです"
        }
    }
}

class InviteService {
    private let db = Firestore.firestore()

    // MARK: - 招待コードの検証

    /// 招待コードが有効かチェックする
    func validateInviteCode(_ code: String) async throws -> InviteCode {
        print("🔍 招待コード検索: \(code)")

        // 1. Firestoreから招待コードを検索
        let snapshot = try await db.collection("invites")
            .whereField("code", isEqualTo: code)
            .whereField("isUsed", isEqualTo: false)
            .limit(to: 1)
            .getDocuments()

        // 2. コードが見つからない場合
        guard let document = snapshot.documents.first else {
            print("❌ 招待コードが見つかりません")
            throw InviteError.codeNotFound
        }

        print("📄 ドキュメントID: \(document.documentID)")

        // 3. ドキュメントをInviteCodeモデルにデコード
        var inviteCode = try document.data(as: InviteCode.self)

        // 4. ドキュメントIDを明示的に設定（念のため）
        if inviteCode.id == nil {
            inviteCode.id = document.documentID
            print("⚠️ ドキュメントIDを手動で設定: \(document.documentID)")
        }

        print("✅ 招待コード取得成功: id=\(inviteCode.id ?? "nil"), code=\(inviteCode.code), isUsed=\(inviteCode.isUsed)")

        // 5. 使用済みチェック
        if inviteCode.isUsed {
            print("❌ 招待コードは既に使用済み")
            throw InviteError.codeAlreadyUsed
        }

        // 6. 有効期限チェック
        if inviteCode.isExpired {
            print("❌ 招待コードの有効期限が切れています")
            throw InviteError.codeExpired
        }

        return inviteCode
    }

    // MARK: - 招待コードを使用済みにする

    /// 招待コードを使用済みに更新する
    func markInviteCodeAsUsed(_ inviteCode: InviteCode, usedBy uid: String) async throws {
        guard let documentId = inviteCode.id else {
            print("❌ 招待コードのドキュメントIDがありません")
            throw InviteError.invalidCode
        }

        print("📝 招待コード更新: ドキュメントID=\(documentId), UID=\(uid)")

        do {
            try await db.collection("invites")
                .document(documentId)
                .updateData([
                    "isUsed": true,
                    "usedBy": uid
                ])
            print("✅ Firestore更新成功")
        } catch {
            print("❌ Firestore更新失敗: \(error.localizedDescription)")
            print("❌ エラー詳細: \(error)")

            // Firestoreエラーの場合、詳細情報を出力
            let nsError = error as NSError
            if nsError.domain == "FIRFirestoreErrorDomain" {
                print("❌ Firestoreエラーコード: \(nsError.code)")
                if nsError.code == 7 {
                    print("❌ 権限エラー: Firestoreセキュリティルールを確認してください")
                }
            }

            throw error
        }
    }

    // MARK: - 招待コード生成

    /// ランダムな招待コードを生成する（6桁の英数字）
    static func generateInviteCode(length: Int = 6) -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }

    // MARK: - 招待コードの作成

    /// 新しい招待コードをFirestoreに作成する（重複チェック付き）
    func createInviteCode(createdBy uid: String, expiresAt: Date? = nil) async throws -> InviteCode {
        // 最大10回まで重複チェックを試行
        for attempt in 1...10 {
            let code = InviteService.generateInviteCode()

            // 既存のコードと重複していないかチェック
            let existingCodes = try await db.collection("invites")
                .whereField("code", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()

            // 重複していない場合は、このコードを使用
            if existingCodes.documents.isEmpty {
                let inviteCode = InviteCode(code: code, createdBy: uid, expiresAt: expiresAt)

                let docRef = db.collection("invites").document()
                try docRef.setData(from: inviteCode)

                var createdInvite = inviteCode
                createdInvite.id = docRef.documentID

                print("✅ 招待コード生成成功: \(code) (試行回数: \(attempt))")
                return createdInvite
            }

            print("⚠️ 招待コード重複: \(code) (試行回数: \(attempt))")
        }

        // 10回試行しても重複が解消されない場合はエラー
        throw NSError(
            domain: "InviteService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "招待コードの生成に失敗しました。もう一度お試しください。"]
        )
    }

    // MARK: - 自分が作成した招待コード一覧を取得

    /// 特定ユーザーが作成した招待コード一覧を取得（使用済み含む全て）
    func fetchInviteCodes(createdBy uid: String) async throws -> [InviteCode] {
        do {
            let snapshot = try await db.collection("invites")
                .whereField("createdBy", isEqualTo: uid)
                .getDocuments()

            let inviteCodes = try snapshot.documents.compactMap { document -> InviteCode? in
                var inviteCode = try document.data(as: InviteCode.self)
                // ドキュメントIDを明示的に設定（@DocumentIDが機能しない場合の対策）
                if inviteCode.id == nil {
                    inviteCode.id = document.documentID
                }
                return inviteCode
            }

            // クライアント側で作成日時の降順にソート
            let sortedCodes = inviteCodes.sorted { $0.createdAt > $1.createdAt }

            // デバッグ用ログ：取得したコードの詳細を出力
            print("📋 招待コード一覧取得: 合計\(sortedCodes.count)件")
            for code in sortedCodes {
                let status = code.isUsed ? "使用済み" : (code.isExpired ? "期限切れ" : "未使用")
                print("  - \(code.code) (ID: \(code.id ?? "nil")): \(status) (作成日: \(code.createdAt))")
            }

            return sortedCodes
        } catch {
            // コレクションが存在しない場合は空配列を返す
            print("❌ 招待コード取得エラー: \(error.localizedDescription)")
            return []
        }
    }
}
