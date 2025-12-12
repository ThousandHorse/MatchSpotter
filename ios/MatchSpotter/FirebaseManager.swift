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
    func fetchPhotos(filter: PhotoFilter) async throws {
        isLoading = true
        errorMessage = nil

        print("🔍 Firestore写真取得開始 - フィルタ: \(filter)")
        print("   🔐 認証状態: \(auth.currentUser != nil ? "ログイン済み" : "未ログイン")")
        if let user = auth.currentUser {
            print("   👤 ユーザーID: \(user.uid)")
        } else {
            print("   ⚠️ 警告: ログインしていません。Firestoreのセキュリティルールによっては読み取りできない可能性があります")
        }

        do {
            var query: Query = db.collection("sharedPhotos")

            switch filter {
            case .all:
                print("   📋 フィルタ: 全件取得")
                query = query.order(by: "uploadedAt", descending: true)

            case .myPhotos:
                guard let userId = currentUser?.id else {
                    isLoading = false
                    throw FirebaseManagerError.notAuthenticated
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
            print("   📄 取得したドキュメント数: \(snapshot.documents.count)件")

            let photos = snapshot.documents.compactMap { document -> SharedPhoto? in
                do {
                    let photo = try document.data(as: SharedPhoto.self)
                    print("      ✓ 写真: \(photo.title) (エリア: \(photo.prefectureName ?? "なし"))")
                    return photo
                } catch {
                    print("      ✗ デコードエラー: \(error)")
                    return nil
                }
            }

            self.sharedPhotos = photos
            print("📸 写真取得成功: \(photos.count)件")
            isLoading = false
        } catch {
            print("❌ 写真取得エラー: \(error)")
            print("   エラー詳細: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   エラーコード: \(nsError.code)")
                print("   エラードメイン: \(nsError.domain)")
            }
            isLoading = false
            throw error
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
            let updatedPhoto: SharedPhoto = try await withCheckedThrowingContinuation { continuation in
                self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                    // トランザクション内でドキュメントを読み取り
                    let document: DocumentSnapshot
                    do {
                        document = try transaction.getDocument(photoRef)
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }

                    // ドキュメントをデコード
                    var currentPhoto: SharedPhoto
                    do {
                        currentPhoto = try document.data(as: SharedPhoto.self)
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }

                    // いいね状態を切り替え
                    if currentPhoto.likedBy.contains(userId) {
                        currentPhoto.likedBy.removeAll { $0 == userId }
                        currentPhoto.likes = max(0, currentPhoto.likes - 1)
                    } else {
                        currentPhoto.likedBy.append(userId)
                        currentPhoto.likes += 1
                    }

                    // トランザクション内で更新
                    do {
                        try transaction.setData(from: currentPhoto, forDocument: photoRef)
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }

                    return currentPhoto
                }) { (result, error) in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let updatedPhoto = result as? SharedPhoto {
                        continuation.resume(returning: updatedPhoto)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "FirebaseManager",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "いいねの更新に失敗しました"]
                        ))
                    }
                }
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

            // Storageから画像を削除 (失敗してもエラーはスローしない)
            // オリジナル画像を削除
            do {
                try await FirebaseStorageManager.shared.deleteImage(imageURL: photo.imageURL)
                print("✅ オリジナル画像削除成功")
            } catch {
                print("⚠️ オリジナル画像の削除に失敗しました: \(error.localizedDescription)")
            }

            // サムネイル画像を削除
            if let thumbnailURL = photo.thumbnailURL {
                do {
                    try await FirebaseStorageManager.shared.deleteImage(imageURL: thumbnailURL)
                    print("✅ サムネイル画像削除成功")
                } catch {
                    print("⚠️ サムネイル画像の削除に失敗しました: \(error.localizedDescription)")
                }
            }
        } catch {
            print("❌ 写真削除エラー: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - 統合データ取得

    /// Firestoreから特定のエリアの写真を取得
    func fetchPhotosForPrefecture(_ prefectureName: String) async -> [SharedPhoto] {
        do {
            print("📍 エリアの写真取得開始: \(prefectureName)")
            let snapshot = try await db.collection("sharedPhotos")
                .whereField("prefectureName", isEqualTo: prefectureName)
                .order(by: "uploadedAt", descending: true)
                .getDocuments()

            print("   📄 \(prefectureName)のドキュメント数: \(snapshot.documents.count)件")

            let photos = snapshot.documents.compactMap { document -> SharedPhoto? in
                do {
                    let photo = try document.data(as: SharedPhoto.self)
                    print("      ✓ 写真: \(photo.title)")
                    return photo
                } catch {
                    print("      ✗ デコードエラー: \(error)")
                    return nil
                }
            }

            return photos
        } catch {
            print("❌ エリアの写真取得エラー: \(error)")
            print("   エラー詳細: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   エラーコード: \(nsError.code)")
                print("   エラードメイン: \(nsError.domain)")

                // インデックスエラーの場合
                if nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 9 {
                    print("   ⚠️ Firestoreインデックスが必要です")
                    print("   ⚠️ Firebase Consoleでインデックスを作成してください")
                    print("   ⚠️ コレクション: sharedPhotos")
                    print("   ⚠️ フィールド: prefectureName (昇順) + uploadedAt (降順)")
                }
            }
            errorMessage = error.localizedDescription
            return []
        }
    }

    /// Firestoreから特定の場所の写真を取得
    func fetchPhotosForLocation(prefectureName: String, locationName: String) async -> [SharedPhoto] {
        do {
            print("📍 場所の写真取得開始: \(prefectureName) > \(locationName)")
            let snapshot = try await db.collection("sharedPhotos")
                .whereField("prefectureName", isEqualTo: prefectureName)
                .whereField("locationName", isEqualTo: locationName)
                .order(by: "uploadedAt", descending: true)
                .getDocuments()

            print("   📄 \(locationName)のドキュメント数: \(snapshot.documents.count)件")

            let photos = snapshot.documents.compactMap { document -> SharedPhoto? in
                do {
                    let photo = try document.data(as: SharedPhoto.self)
                    print("      ✓ 写真: \(photo.title)")
                    return photo
                } catch {
                    print("      ✗ デコードエラー: \(error)")
                    return nil
                }
            }

            return photos
        } catch {
            print("❌ 場所の写真取得エラー: \(error)")
            print("   エラー詳細: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   エラーコード: \(nsError.code)")
                print("   エラードメイン: \(nsError.domain)")

                // インデックスエラーの場合
                if nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 9 {
                    print("   ⚠️ Firestoreインデックスが必要です")
                    print("   ⚠️ Firebase Consoleでインデックスを作成してください")
                    print("   ⚠️ コレクション: sharedPhotos")
                    print("   ⚠️ フィールド: prefectureName (昇順) + locationName (昇順) + uploadedAt (降順)")
                }
            }
            errorMessage = error.localizedDescription
            return []
        }
    }

    /// Firestoreから全てのエリア名を取得
    func fetchAllPrefectureNames() async -> Set<String> {
        do {
            let snapshot = try await db.collection("sharedPhotos")
                .getDocuments()

            let names = snapshot.documents.compactMap { document -> String? in
                try? document.data(as: SharedPhoto.self).prefectureName
            }

            return Set(names)
        } catch {
            print("❌ エリア名取得エラー: \(error)")
            return []
        }
    }

    /// Firestoreから特定エリアの全ての場所名と写真数を取得
    func fetchLocationNamesForPrefecture(_ prefectureName: String) async -> [(name: String, count: Int)] {
        do {
            let snapshot = try await db.collection("sharedPhotos")
                .whereField("prefectureName", isEqualTo: prefectureName)
                .getDocuments()

            let locations = snapshot.documents.compactMap { document -> String? in
                guard let photo = try? document.data(as: SharedPhoto.self) else { return nil }
                return photo.locationName
            }

            // 場所名ごとに写真数をカウント
            var locationCounts: [String: Int] = [:]
            for location in locations {
                locationCounts[location, default: 0] += 1
            }

            return locationCounts.map { (name: $0.key, count: $0.value) }
        } catch {
            print("❌ 場所名取得エラー: \(error)")
            return []
        }
    }

    // MARK: - エリアサマリー取得（最適化版）

    /// Firestoreから全エリアのサマリー情報を取得（軽量・高速）
    func fetchPrefecturesSummary() async -> [PrefectureSummary] {
        do {
            print("📊 エリアサマリー取得開始")
            let snapshot = try await db.collection("prefecturesSummary")
                .order(by: "photoCount", descending: true)
                .getDocuments()

            print("   📄 取得したサマリードキュメント数: \(snapshot.documents.count)件")

            let summaries = snapshot.documents.compactMap { document -> PrefectureSummary? in
                do {
                    let summary = try document.data(as: PrefectureSummary.self)
                    print("      ✓ エリア: \(summary.prefectureName), 写真数: \(summary.photoCount)")
                    return summary
                } catch {
                    print("      ✗ デコードエラー: \(error)")
                    return nil
                }
            }

            print("✅ エリアサマリー取得成功: \(summaries.count)個")
            return summaries
        } catch {
            print("❌ エリアサマリー取得エラー: \(error)")
            print("   エラー詳細: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   エラーコード: \(nsError.code)")
                print("   エラードメイン: \(nsError.domain)")
            }
            return []
        }
    }
}
