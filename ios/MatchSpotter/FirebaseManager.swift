//
//  FirebaseManager.swift
//  MatchSpotter
//
//  Created by Claude
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Firebase操作のエラー型
enum FirebaseManagerError: LocalizedError {
    case notAuthenticated
    case photoNotFound
    case permissionDenied
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "ログインが必要です"
        case .photoNotFound:
            return "写真が見つかりません"
        case .permissionDenied:
            return "自分の投稿のみ削除できます"
        case .userNotFound:
            return "ユーザー情報が見つかりません"
        }
    }
}

/// Firebase認証とFirestore操作を管理するクラス
@MainActor
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var sharedPhotos: [SharedPhoto] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = FirebaseConfig.shared.db
    private let auth = FirebaseConfig.shared.auth
    private var authStateListener: AuthStateDidChangeListenerHandle?

    private init() {
        // 認証状態の監視
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                if let user = user {
                    await self?.fetchCurrentUser(uid: user.uid)
                } else {
                    self?.currentUser = nil
                }
            }
        }
    }

    deinit {
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
        }
    }

    // MARK: - 認証関連

    /// メールアドレスとパスワードでサインアップ
    func signUp(email: String, password: String, displayName: String?) async throws {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            let user = User(id: result.user.uid, email: email, displayName: displayName)

            // Firestoreにユーザー情報を保存
            try db.collection("users").document(result.user.uid).setData(from: user)
            self.currentUser = user
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// メールアドレスとパスワードでログイン
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            await fetchCurrentUser(uid: result.user.uid)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// 匿名ログイン
    func signInAnonymously() async throws {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await auth.signInAnonymously()
            let user = User(id: result.user.uid, email: "anonymous", displayName: "ゲストユーザー")

            // Firestoreにユーザー情報を保存
            try db.collection("users").document(result.user.uid).setData(from: user)
            self.currentUser = user
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// ログアウト
    func signOut() throws {
        try auth.signOut()
        currentUser = nil
        sharedPhotos = []
    }

    /// 現在のユーザー情報を取得
    private func fetchCurrentUser(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            self.currentUser = try document.data(as: User.self)
        } catch {
            print("ユーザー情報の取得エラー: \(error)")
        }
    }

    // MARK: - Firestore操作（写真関連）

    /// 共有写真を取得（全件）
    func fetchSharedPhotos() async {
        isLoading = true

        do {
            let snapshot = try await db.collection("sharedPhotos")
                .order(by: "uploadedAt", descending: true)
                .limit(to: 50)
                .getDocuments()

            self.sharedPhotos = snapshot.documents.compactMap { document in
                try? document.data(as: SharedPhoto.self)
            }
            isLoading = false
        } catch {
            print("写真取得エラー: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// フィルタを適用して写真を取得
    func fetchPhotos(filter: PhotoFilter) async {
        isLoading = true

        do {
            var query: Query = db.collection("sharedPhotos")

            switch filter {
            case .all:
                query = query.order(by: "uploadedAt", descending: true).limit(to: 50)

            case .myPhotos:
                guard let userId = currentUser?.id else {
                    isLoading = false
                    errorMessage = "ログインが必要です"
                    return
                }
                query = query.whereField("userId", isEqualTo: userId)
                    .order(by: "uploadedAt", descending: true)

            case .prefecture(let name):
                query = query.whereField("prefectureName", isEqualTo: name)
                    .order(by: "uploadedAt", descending: true)

            case .location(let name):
                query = query.whereField("locationName", isEqualTo: name)
                    .order(by: "uploadedAt", descending: true)

            case .recent:
                let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                query = query.whereField("uploadedAt", isGreaterThan: oneWeekAgo)
                    .order(by: "uploadedAt", descending: true)
            }

            let snapshot = try await query.getDocuments()
            self.sharedPhotos = snapshot.documents.compactMap { document in
                try? document.data(as: SharedPhoto.self)
            }
            isLoading = false
        } catch {
            print("写真取得エラー: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// 写真にいいねを追加/削除
    func toggleLike(photo: SharedPhoto) async throws {
        // 写真IDの確認
        guard let photoId = photo.id else {
            throw FirebaseManagerError.photoNotFound
        }

        // 認証状態の確認
        guard let userId = currentUser?.id else {
            throw FirebaseManagerError.notAuthenticated
        }

        let photoRef = db.collection("sharedPhotos").document(photoId)

        do {
            let updatedPhoto: SharedPhoto = try await db.runTransaction { transaction, _ in
                let document = try transaction.getDocument(photoRef)
                var currentPhoto = try document.data(as: SharedPhoto.self)

                if currentPhoto.likedBy.contains(userId) {
                    currentPhoto.likedBy.removeAll { $0 == userId }
                    currentPhoto.likes = max(0, currentPhoto.likes - 1)
                } else {
                    currentPhoto.likedBy.append(userId)
                    currentPhoto.likes += 1
                }

                try transaction.setData(from: currentPhoto, forDocument: photoRef)
                return currentPhoto
            }

            // ローカルの配列も更新
            if let index = sharedPhotos.firstIndex(where: { $0.id == photoId }) {
                sharedPhotos[index] = updatedPhoto
            }
        } catch {
            print("いいね更新エラー: \(error)")
            throw error
        }
    }

    /// 写真を削除
    func deletePhoto(photo: SharedPhoto) async throws {
        // 写真IDの確認
        guard let photoId = photo.id else {
            throw FirebaseManagerError.photoNotFound
        }

        // 認証状態の確認
        guard let currentUserId = currentUser?.id else {
            throw FirebaseManagerError.notAuthenticated
        }

        // クライアント側でも投稿者のみ削除可能に制限
        guard photo.userId == currentUserId else {
            throw FirebaseManagerError.permissionDenied
        }

        // Firestoreから削除
        do {
            try await db.collection("sharedPhotos").document(photoId).delete()

            // ローカルの配列からも削除
            sharedPhotos.removeAll { $0.id == photoId }

            print("✅ 写真削除成功: \(photoId)")
        } catch {
            print("❌ 写真削除エラー: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
