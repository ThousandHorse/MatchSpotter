import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
import OSLog

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
    @Published var hasMorePhotos = false

    private let db = FirebaseConfig.shared.db
    private let auth = FirebaseConfig.shared.auth
    private var authStateListener: AuthStateDidChangeListenerHandle?

    /// ユーザーの表示名を取得（nickname > displayName > emailの@より前 の優先順位）
    var userDisplayName: String? {
        guard let user = currentUser else { return nil }

        // nicknameが設定されていればそれを使用
        if let nickname = user.nickname, !nickname.isEmpty {
            return nickname
        }

        // displayNameが設定されていればそれを使用
        if let displayName = user.displayName, !displayName.isEmpty {
            return displayName
        }

        // どちらもない場合はemailの@より前を使用
        return user.email.components(separatedBy: "@").first ?? "ユーザー"
    }

    // ページネーション用
    private var lastDocument: DocumentSnapshot?
    private var currentFilter: PhotoFilter?
    private let pageSize = 50

    // Logger
    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "FirebaseManager")

    /// Firestoreページネーション結果
    struct PhotoPage {
        let photos: [SharedPhoto]
        let lastDocument: DocumentSnapshot?
        let hasMore: Bool
    }

    private func buildQuery(for filter: PhotoFilter) throws -> Query {
        var query: Query = db.collection("sharedPhotos")

        switch filter {
        case .all:
            logger.debug("   📋 フィルタ: 全件取得")
            query = query.order(by: "uploadedAt", descending: true)

        case .myPhotos:
            guard let userId = currentUser?.id else {
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

        return query
    }

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

            // displayNameが空の場合、メールアドレスの@より前を使用
            let finalDisplayName: String
            if let name = displayName, !name.isEmpty {
                finalDisplayName = name
            } else {
                finalDisplayName = email.components(separatedBy: "@").first ?? "ユーザー"
            }

            let user = User(id: result.user.uid, email: email, displayName: finalDisplayName)

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

    /// ユーザープロフィールを更新
    func updateUserProfile(nickname: String) async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "FirebaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザーIDが見つかりません"])
        }

        // Firestoreのユーザードキュメントを更新
        try await db.collection("users").document(userId).updateData([
            "nickname": nickname
        ])

        // ローカルのcurrentUserも更新
        if var user = currentUser {
            user.nickname = nickname
            currentUser = user
        }

        logger.info("✅ ユーザープロフィール更新成功: \(nickname)")
    }

    /// 現在のユーザー情報を取得
    private func fetchCurrentUser(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            var user = try document.data(as: User.self)

            // displayNameがnilまたは空の場合、デフォルト値を設定
            if user.displayName == nil || user.displayName?.isEmpty == true {
                let defaultName = user.email.components(separatedBy: "@").first ?? "ユーザー"
                user.displayName = defaultName

                // Firestoreにも更新を保存
                do {
                    try await db.collection("users").document(uid).updateData([
                        "displayName": defaultName
                    ])
                    logger.info("デフォルトのdisplayNameを設定: \(defaultName)")
                } catch {
                    logger.error("デフォルトのdisplayName更新に失敗: \(error.localizedDescription)")
                }
            }

            self.currentUser = user
        } catch {
            logger.error("ユーザー情報の取得エラー: \(error.localizedDescription)")
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
            logger.error("写真取得エラー: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// フィルタを適用して写真を取得（初回読み込み）
    func fetchPhotos(filter: PhotoFilter) async throws {
        isLoading = true
        errorMessage = nil

        // ページネーション状態をリセット
        lastDocument = nil
        currentFilter = filter
        hasMorePhotos = false

        logger.debug("🔍 Firestore写真取得開始 - フィルタ: \(String(describing: filter))")
        logger.debug("   📏 ページサイズ: \(self.pageSize)件")
        logger.debug("   🔐 認証状態: \(self.auth.currentUser != nil ? "ログイン済み" : "未ログイン")")
        if let user = auth.currentUser {
            logger.debug("   👤 ユーザーID: \(user.uid)")
        } else {
            logger.warning("   ⚠️ 警告: ログインしていません。Firestoreのセキュリティルールによっては読み取りできない可能性があります")
        }

        do {
            var query = try buildQuery(for: filter)
            query = query.limit(to: pageSize)

            let snapshot = try await query.getDocuments()
            logger.debug("   📄 取得したドキュメント数: \(snapshot.documents.count)件")

            let photos = snapshot.documents.compactMap { document -> SharedPhoto? in
                do {
                    let photo = try document.data(as: SharedPhoto.self)
                    logger.debug("      ✓ 写真: \(photo.title) (エリア: \(photo.prefectureName ?? "なし"))")
                    return photo
                } catch {
                    logger.error("      ✗ デコードエラー: \(error.localizedDescription)")
                    return nil
                }
            }

            self.sharedPhotos = photos

            // 次のページがあるかチェック
            if snapshot.documents.count == pageSize {
                lastDocument = snapshot.documents.last
                hasMorePhotos = true
                logger.debug("   📄 次のページが存在する可能性があります")
            } else {
                hasMorePhotos = false
                logger.debug("   📄 全てのデータを取得しました")
            }

            logger.info("📸 写真取得成功: \(photos.count)件")
            isLoading = false
        } catch {
            logger.error("❌ 写真取得エラー: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                logger.error("   エラーコード: \(nsError.code)")
                logger.error("   エラードメイン: \(nsError.domain)")
            }
            isLoading = false
            throw error
        }
    }

    /// 次のページの写真を追加取得（ページネーション）
    func fetchMorePhotos() async throws {
        // 次のページが存在しない、または既に読み込み中の場合は何もしない
        guard hasMorePhotos, !isLoading, let lastDoc = lastDocument, let filter = currentFilter else {
            logger.warning("⚠️ 次のページがないか、既に読み込み中です")
            return
        }

        isLoading = true
        logger.debug("🔍 次のページを読み込み中...")

        do {
            var query = try buildQuery(for: filter)

            // 最後のドキュメントから開始
            query = query.start(afterDocument: lastDoc)
                .limit(to: pageSize)

            let snapshot = try await query.getDocuments()
            logger.debug("   📄 追加取得したドキュメント数: \(snapshot.documents.count)件")

            let photos = snapshot.documents.compactMap { document -> SharedPhoto? in
                do {
                    let photo = try document.data(as: SharedPhoto.self)
                    return photo
                } catch {
                    logger.error("      ✗ デコードエラー: \(error.localizedDescription)")
                    return nil
                }
            }

            // 既存の配列に追加
            self.sharedPhotos.append(contentsOf: photos)

            // 次のページがあるかチェック
            if snapshot.documents.count == pageSize {
                lastDocument = snapshot.documents.last
                hasMorePhotos = true
                logger.debug("   📄 さらに次のページが存在する可能性があります")
            } else {
                hasMorePhotos = false
                lastDocument = nil
                logger.debug("   📄 全てのデータを取得しました")
            }

            logger.info("📸 追加取得成功: +\(photos.count)件（合計: \(self.sharedPhotos.count)件）")
            isLoading = false
        } catch {
            logger.error("❌ 追加取得エラー: \(error.localizedDescription)")
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

        let result = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            do {
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
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }

        guard let updatedPhoto = result as? SharedPhoto else {
            throw FirebaseManagerError.photoNotFound
        }

        // ローカルの配列も更新
        if let index = sharedPhotos.firstIndex(where: { $0.id == photoId }) {
            sharedPhotos[index] = updatedPhoto
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

            logger.info("✅ 写真削除成功: \(photoId)")

            // Storageから画像を削除 (失敗してもエラーはスローしない)
            // オリジナル画像を削除
            do {
                try await FirebaseStorageManager.shared.deleteImage(imageURL: photo.imageURL)
                logger.info("✅ オリジナル画像削除成功")
            } catch {
                logger.warning("⚠️ オリジナル画像の削除に失敗しました: \(error.localizedDescription)")
            }

            // サムネイル画像を削除
            if let thumbnailURL = photo.thumbnailURL {
                do {
                    try await FirebaseStorageManager.shared.deleteImage(imageURL: thumbnailURL)
                    logger.info("✅ サムネイル画像削除成功")
                } catch {
                    logger.warning("⚠️ サムネイル画像の削除に失敗しました: \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("❌ 写真削除エラー: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - 統合データ取得

    /// Firestoreから特定のエリアの写真をページネーション取得
    func fetchPhotosForPrefecture(_ prefectureName: String, lastDocument: DocumentSnapshot? = nil, pageSize: Int? = nil) async throws -> PhotoPage {
        let limit = pageSize ?? self.pageSize

        do {
            logger.debug("📍 エリアの写真取得開始: \(prefectureName)")
            var query = db.collection("sharedPhotos")
                .whereField("prefectureName", isEqualTo: prefectureName)
                .order(by: "uploadedAt", descending: true)
                .limit(to: limit)

            if let lastDocument = lastDocument {
                query = query.start(afterDocument: lastDocument)
            }

            let snapshot = try await query.getDocuments()
            logger.debug("   📄 \(prefectureName)のドキュメント数: \(snapshot.documents.count)件")

            return buildPhotoPage(from: snapshot, limit: limit, logPrefix: "エリア")
        } catch {
            logger.error("❌ エリアの写真取得エラー: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                logger.error("   エラーコード: \(nsError.code)")
                logger.error("   エラードメイン: \(nsError.domain)")

                // インデックスエラーの場合
                if nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 9 {
                    logger.warning("   ⚠️ Firestoreインデックスが必要です")
                    logger.warning("   ⚠️ Firebase Consoleでインデックスを作成してください")
                    logger.warning("   ⚠️ コレクション: sharedPhotos")
                    logger.warning("   ⚠️ フィールド: prefectureName (昇順) + uploadedAt (降順)")
                }
            }
            throw error
        }
    }

    /// Firestoreから特定の場所の写真をページネーション取得
    func fetchPhotosForLocation(prefectureName: String, locationName: String, lastDocument: DocumentSnapshot? = nil, pageSize: Int? = nil) async throws -> PhotoPage {
        let limit = pageSize ?? self.pageSize

        do {
            logger.debug("📍 場所の写真取得開始: \(prefectureName) > \(locationName)")
            var query = db.collection("sharedPhotos")
                .whereField("prefectureName", isEqualTo: prefectureName)
                .whereField("locationName", isEqualTo: locationName)
                .order(by: "uploadedAt", descending: true)
                .limit(to: limit)

            if let lastDocument = lastDocument {
                query = query.start(afterDocument: lastDocument)
            }

            let snapshot = try await query.getDocuments()
            logger.debug("   📄 \(locationName)のドキュメント数: \(snapshot.documents.count)件")

            return buildPhotoPage(from: snapshot, limit: limit, logPrefix: "場所")
        } catch {
            logger.error("❌ 場所の写真取得エラー: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                logger.error("   エラーコード: \(nsError.code)")
                logger.error("   エラードメイン: \(nsError.domain)")

                // インデックスエラーの場合
                if nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 9 {
                    logger.warning("   ⚠️ Firestoreインデックスが必要です")
                    logger.warning("   ⚠️ Firebase Consoleでインデックスを作成してください")
                    logger.warning("   ⚠️ コレクション: sharedPhotos")
                    logger.warning("   ⚠️ フィールド: prefectureName (昇順) + locationName (昇順) + uploadedAt (降順)")
                }
            }
            throw error
        }
    }

    private func buildPhotoPage(from snapshot: QuerySnapshot, limit: Int, logPrefix: String) -> PhotoPage {
        let photos = snapshot.documents.compactMap { document -> SharedPhoto? in
            do {
                let photo = try document.data(as: SharedPhoto.self)
                logger.debug("      ✓ 写真: \(photo.title)")
                return photo
            } catch {
                logger.error("      ✗ デコードエラー: \(error.localizedDescription)")
                return nil
            }
        }

        let hasMore = snapshot.documents.count == limit
        let lastDocument = hasMore ? snapshot.documents.last : nil

        logger.info("✅ \(logPrefix)の写真取得成功: \(photos.count)件 / hasMore=\(hasMore)")
        return PhotoPage(photos: photos, lastDocument: lastDocument, hasMore: hasMore)
    }

    /// 位置情報がある共有写真を取得（地図表示用）
    func fetchPhotosWithLocation() async throws -> [SharedPhoto] {
        do {
            logger.debug("🗺️ 位置情報付き写真取得開始")

            // hasLocationフィールドを使ってサーバーサイドでフィルタリング
            let snapshot = try await db.collection("sharedPhotos")
                .whereField("hasLocation", isEqualTo: true)
                .order(by: "uploadedAt", descending: true)
                .getDocuments()

            logger.debug("   📄 取得したドキュメント数: \(snapshot.documents.count)件")

            // デコードして返す
            let photosWithLocation = snapshot.documents.compactMap { document -> SharedPhoto? in
                do {
                    let photo = try document.data(as: SharedPhoto.self)
                    logger.debug("      ✓ 位置情報付き: \(photo.title) at (\(photo.latitude ?? 0), \(photo.longitude ?? 0))")
                    return photo
                } catch {
                    logger.error("      ✗ デコードエラー: \(error.localizedDescription)")
                    return nil
                }
            }

            logger.info("✅ 位置情報付き写真取得成功: \(photosWithLocation.count)件")
            return photosWithLocation
        } catch {
            logger.error("❌ 位置情報付き写真取得エラー: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                logger.error("   エラーコード: \(nsError.code)")
                logger.error("   エラードメイン: \(nsError.domain)")

                // 複合インデックスが必要な場合のエラー（9: FAILED_PRECONDITION）
                if nsError.code == 9 {
                    logger.error("   ⚠️ Firestoreの複合インデックスが必要です")
                    logger.error("   以下のURLからインデックスを作成してください:")
                    if let errorMessage = nsError.userInfo["NSLocalizedDescription"] as? String,
                       let url = errorMessage.components(separatedBy: "https://").last?.components(separatedBy: " ").first {
                        logger.error("   https://\(url)")
                    }
                }
            }
            throw error
        }
    }

    // MARK: - エリアサマリー取得（最適化版）

    /// Firestoreから全エリアのサマリー情報を取得（軽量・高速）
    func fetchPrefecturesSummary() async throws -> [PrefectureSummary] {
        do {
            logger.debug("📊 エリアサマリー取得開始")
            let snapshot = try await db.collection("prefecturesSummary")
                .order(by: "photoCount", descending: true)
                .getDocuments()

            logger.debug("   📄 取得したサマリードキュメント数: \(snapshot.documents.count)件")

            let summaries = snapshot.documents.compactMap { document -> PrefectureSummary? in
                do {
                    let summary = try document.data(as: PrefectureSummary.self)
                    logger.debug("      ✓ エリア: \(summary.prefectureName), 写真数: \(summary.photoCount)")
                    return summary
                } catch {
                    logger.error("      ✗ デコードエラー: \(error.localizedDescription)")
                    return nil
                }
            }

            logger.info("✅ エリアサマリー取得成功: \(summaries.count)個")
            return summaries
        } catch {
            logger.error("❌ エリアサマリー取得エラー: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                logger.error("   エラーコード: \(nsError.code)")
                logger.error("   エラードメイン: \(nsError.domain)")
            }
            throw error
        }
    }
}
