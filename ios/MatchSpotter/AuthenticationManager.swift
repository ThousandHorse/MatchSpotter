//
//  AuthenticationManager.swift
//  MatchSpotter
//
//  Firebase Authentication を管理するクラス
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isAuthenticated = false
    @Published var isAdmin = false
    @Published var errorMessage: String?

    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private let userService = UserService()

    init() {
        // 認証状態の監視を開始
        registerAuthStateHandler()
    }

    deinit {
        // 認証状態の監視を解除
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }

    // MARK: - 認証状態の監視

    func registerAuthStateHandler() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.user = user
            self.isAuthenticated = user != nil

            // ユーザー情報を取得して管理者フラグを設定
            if let uid = user?.uid {
                Task {
                    await self.fetchUserAdminStatus(uid: uid)
                }
            } else {
                self.isAdmin = false
            }
        }
    }

    // MARK: - 管理者ステータスの取得

    private func fetchUserAdminStatus(uid: String) async {
        do {
            if let appUser = try await userService.fetchUser(uid: uid) {
                self.isAdmin = appUser.isAdmin
            } else {
                self.isAdmin = false
            }
        } catch {
            print("管理者ステータスの取得エラー: \(error.localizedDescription)")
            self.isAdmin = false
        }
    }

    // MARK: - メールアドレス・パスワードでのサインアップ（招待コード必須）

    func signUp(email: String, password: String, inviteCode: String, nickname: String?) async throws {
        let inviteService = InviteService()
        let userService = UserService()
        var createdUser: FirebaseAuth.User?

        do {
            // ① 招待コードの事前検証（ユーザー作成前に無効なコードを検出）
            // 注意: 事前検証のみで、まだ使用済みにはマークしません
            print("🔍 招待コード事前検証: \(inviteCode)")
            _ = try await inviteService.validateInviteCode(inviteCode)
            print("✅ 招待コード事前検証成功")

            // ② FirebaseAuthでユーザー作成
            print("👤 ユーザー作成開始")
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid
            createdUser = result.user
            print("✅ ユーザー作成成功: \(uid)")

            // ③ Firestoreのusersコレクションにユーザー作成
            print("📝 Firestoreにユーザー情報を保存開始")
            try await userService.createUser(uid: uid, email: email, nickname: nickname)
            print("✅ ユーザー情報保存成功")

            // ④ 招待コードを検証して使用済みにマーク（トランザクション内でアトミックに実行）
            // トランザクション内で再度検証するため、競合状態を防げます
            print("🔄 招待コード検証・更新開始（トランザクション）")
            _ = try await inviteService.validateAndMarkInviteCodeAsUsed(inviteCode, usedBy: uid)
            print("✅ 招待コード検証・更新成功")

            // ⑤ 認証状態を更新
            self.user = result.user
            self.isAuthenticated = true
            self.errorMessage = nil
            print("✅ サインアップ完了")

        } catch let error as InviteError {
            print("❌ 招待コードエラー: \(error.localizedDescription)")
            // 招待コードエラー
            self.errorMessage = error.localizedDescription

            // ユーザーが作成されていたら削除
            if let user = createdUser {
                try? await user.delete()
                print("🗑️ 作成されたユーザーを削除しました")
            }

            throw error
        } catch {
            print("❌ サインアップエラー: \(error.localizedDescription)")
            print("❌ エラー詳細: \(error)")

            // その他のエラー
            self.errorMessage = error.localizedDescription

            // ユーザーが作成されていたら削除
            if let user = createdUser {
                try? await user.delete()
                print("🗑️ 作成されたユーザーを削除しました")
            }

            throw error
        }
    }

    // MARK: - メールアドレス・パスワードでのサインイン

    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.user = result.user
            self.isAuthenticated = true
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - サインアウト

    func signOut() throws {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.isAuthenticated = false
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - パスワードリセットメール送信

    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
    }
}
