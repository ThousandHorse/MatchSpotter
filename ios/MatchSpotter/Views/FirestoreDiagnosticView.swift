//
//  FirestoreDiagnosticView.swift
//  MatchSpotter
//
//  Firestore接続とデータ取得の診断ツール
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import OSLog

/// Firestore診断ビュー - 開発用
struct FirestoreDiagnosticView: View {
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @State private var diagnosticResults: [String] = []
    @State private var isRunning = false
    @State private var testPhotoCount = 0
    @State private var authStatus = ""
    @State private var firestoreStatus = ""

    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "FirestoreDiagnosticView")

    var body: some View {
        NavigationStack {
            List {
                Section("認証状態") {
                    Text(authStatus.isEmpty ? "確認中..." : authStatus)
                        .font(.caption)
                }

                Section("Firestore接続状態") {
                    Text(firestoreStatus.isEmpty ? "確認中..." : firestoreStatus)
                        .font(.caption)
                }

                Section("写真データ") {
                    Text("取得した写真数: \(testPhotoCount)枚")
                        .font(.caption)
                }

                Section("診断ログ") {
                    if diagnosticResults.isEmpty {
                        Text("診断を実行してください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(diagnosticResults.indices, id: \.self) { index in
                            Text(diagnosticResults[index])
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(getLogColor(for: diagnosticResults[index]))
                        }
                    }
                }

                Section {
                    Button {
                        Task {
                            await runDiagnostics()
                        }
                    } label: {
                        HStack {
                            if isRunning {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isRunning ? "診断実行中..." : "診断を実行")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isRunning)
                }
            }
            .navigationTitle("Firestore診断")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await checkInitialStatus()
        }
    }

    private func checkInitialStatus() async {
        // 認証状態の確認
        if let user = Auth.auth().currentUser {
            authStatus = "✅ ログイン済み\nユーザーID: \(user.uid)\nメール: \(user.email ?? "なし")"
        } else {
            authStatus = "❌ 未ログイン"
        }

        // Firestore接続の基本確認
        firestoreStatus = "接続テスト未実施"
    }

    private func runDiagnostics() async {
        isRunning = true
        diagnosticResults = []

        addLog("=== Firestore診断開始 ===")

        // 1. 認証状態の確認
        addLog("1️⃣ 認証状態を確認中...")
        if let user = Auth.auth().currentUser {
            addLog("✅ ログイン済み")
            addLog("   ユーザーID: \(user.uid)")
            addLog("   メール: \(user.email ?? "匿名")")
        } else {
            addLog("❌ ログインしていません")
            addLog("   セキュリティルールで認証が必要な場合、データ取得に失敗します")
        }

        // 2. Firestore接続テスト
        addLog("2️⃣ Firestore接続テスト...")
        let db = Firestore.firestore()

        do {
            // コレクション一覧の取得を試みる（権限があれば）
            let snapshot = try await db.collection("sharedPhotos").limit(to: 1).getDocuments()
            addLog("✅ Firestore接続成功")
            firestoreStatus = "✅ 接続成功"
        } catch {
            addLog("❌ Firestore接続エラー: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                addLog("   エラーコード: \(nsError.code)")
                addLog("   エラードメイン: \(nsError.domain)")

                if nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 7 {
                    addLog("   ⚠️ 権限エラー - セキュリティルールを確認してください")
                }
            }
            firestoreStatus = "❌ 接続失敗"
        }

        // 3. sharedPhotosコレクションの確認
        addLog("3️⃣ sharedPhotosコレクションを確認中...")
        do {
            let snapshot = try await db.collection("sharedPhotos").getDocuments()
            let count = snapshot.documents.count
            testPhotoCount = count

            if count == 0 {
                addLog("⚠️ sharedPhotosコレクションは空です（0件）")
                addLog("   写真を公開すると、ここにデータが保存されます")
            } else {
                addLog("✅ sharedPhotosコレクションに\(count)件のドキュメントがあります")

                // 最初の3件のドキュメントを確認
                let limit = min(3, count)
                for (index, document) in snapshot.documents.prefix(limit).enumerated() {
                    addLog("   📄 ドキュメント\(index + 1): \(document.documentID)")

                    if let photo = try? document.data(as: SharedPhoto.self) {
                        addLog("      ✓ タイトル: \(photo.title)")
                        addLog("      ✓ エリア: \(photo.prefectureName ?? "nil")")
                        addLog("      ✓ 場所: \(photo.locationName ?? "nil")")
                        addLog("      ✓ ユーザーID: \(photo.userId)")
                    } else {
                        addLog("      ✗ デコードエラー - データ構造が不正です")
                    }
                }
            }
        } catch {
            addLog("❌ sharedPhotosコレクション取得エラー: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                addLog("   エラーコード: \(nsError.code)")

                if nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 7 {
                    addLog("   ⚠️ 読み取り権限がありません")
                    addLog("   ⚠️ Firebase Console > Firestore > ルール を確認してください")
                    addLog("   ⚠️ 必要なルール:")
                    addLog("   match /sharedPhotos/{photoId} {")
                    addLog("     allow read: if request.auth != null;")
                    addLog("   }")
                }
            }
        }

        // 4. インデックスのテスト
        addLog("4️⃣ Firestoreインデックスをテスト中...")
        do {
            let snapshot = try await db.collection("sharedPhotos")
                .whereField("prefectureName", isEqualTo: "東京")
                .order(by: "uploadedAt", descending: true)
                .limit(to: 1)
                .getDocuments()

            addLog("✅ インデックス (prefectureName + uploadedAt) OK")
        } catch {
            if let nsError = error as NSError?, nsError.code == 9 {
                addLog("❌ インデックスが必要です")
                addLog("   Firebase Console > Firestore > インデックス で以下を作成:")
                addLog("   - コレクション: sharedPhotos")
                addLog("   - フィールド1: prefectureName (昇順)")
                addLog("   - フィールド2: uploadedAt (降順)")
            } else {
                addLog("⚠️ インデックステストスキップ: \(error.localizedDescription)")
            }
        }

        // 5. FirebaseManagerを使った取得テスト
        addLog("5️⃣ FirebaseManagerで写真を取得中...")
        var managerPhotoCount = 0
        do {
            try await firebaseManager.fetchPhotos(filter: .all)
            managerPhotoCount = firebaseManager.sharedPhotos.count
            addLog("✅ FirebaseManager経由で\(managerPhotoCount)件の写真を取得")
        } catch {
            addLog("❌ FirebaseManager取得エラー: \(error.localizedDescription)")
        }

        if managerPhotoCount == 0 && testPhotoCount > 0 {
            addLog("⚠️ Firestoreにデータはあるが、FirebaseManagerで取得できません")
            addLog("   デコードエラーまたはフィルタの問題の可能性があります")
        }

        addLog("=== 診断完了 ===")
        addLog("")
        addLog("📝 結果サマリー:")
        addLog("- 認証: \(Auth.auth().currentUser != nil ? "✅" : "❌")")
        addLog("- Firestore接続: \(firestoreStatus)")
        addLog("- sharedPhotos件数: \(testPhotoCount)件")
        addLog("- 取得可能写真数: \(managerPhotoCount)件")

        isRunning = false
    }

    private func addLog(_ message: String) {
        diagnosticResults.append(message)
        logger.debug("[Diagnostic] \(message)")
    }

    private func getLogColor(for log: String) -> Color {
        if log.contains("❌") {
            return .red
        } else if log.contains("⚠️") {
            return .orange
        } else if log.contains("✅") {
            return .green
        } else if log.contains("===") {
            return .blue
        }
        return .primary
    }
}

#Preview {
    FirestoreDiagnosticView()
}
