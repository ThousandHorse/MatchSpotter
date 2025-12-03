//
//  AdminInviteCodeView.swift
//  MatchSpotter
//
//  管理者用招待コード発行画面
//

import SwiftUI
import FirebaseAuth

struct AdminInviteCodeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var inviteCodes: [InviteCode] = []
    @State private var isLoading = false
    @State private var isGenerating = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private let inviteService = InviteService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // 招待コード生成ボタン
                    Button(action: generateInviteCode) {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Label("新しい招待コードを生成", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .background(Color.blue)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(isGenerating)

                    // 招待コード一覧
                    if isLoading {
                        ProgressView("読み込み中...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if inviteCodes.isEmpty {
                        ContentUnavailableView(
                            "招待コードがありません",
                            systemImage: "ticket",
                            description: Text("上のボタンから新しい招待コードを生成してください")
                        )
                    } else {
                        List {
                            ForEach(inviteCodes, id: \.id) { inviteCode in
                                InviteCodeRow(inviteCode: inviteCode)
                            }
                        }
                        .listStyle(.insetGrouped)
                        .refreshable {
                            await loadInviteCodes()
                        }
                    }
                }
            }
            .navigationTitle("招待コード管理")
            .navigationBarTitleDisplayMode(.inline)
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .task {
                await loadInviteCodes()
            }
        }
    }

    // MARK: - 招待コード生成

    private func generateInviteCode() {
        guard let uid = authManager.user?.uid else { return }

        isGenerating = true

        Task {
            do {
                // 30日後に有効期限を設定
                let expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: Date())
                let newCode = try await inviteService.createInviteCode(
                    createdBy: uid,
                    expiresAt: expiresAt
                )

                alertTitle = "招待コード生成成功"
                alertMessage = "招待コード: \(newCode.code)\n\nこのコードを共有してください。"
                showAlert = true

                // リストを再読み込み
                await loadInviteCodes()
            } catch {
                alertTitle = "エラー"
                alertMessage = getFirestoreErrorMessage(error, defaultMessage: "招待コードの生成に失敗しました")
                showAlert = true
            }

            isGenerating = false
        }
    }

    // MARK: - 招待コード一覧読み込み

    private func loadInviteCodes() async {
        guard let uid = authManager.user?.uid else { return }

        isLoading = true

        do {
            inviteCodes = try await inviteService.fetchInviteCodes(createdBy: uid)
            // エラーがなければ正常に読み込み完了（空の場合も含む）
        } catch {
            // InviteServiceで空配列を返すので、通常はここには来ない
            // 万が一エラーが発生した場合のみアラート表示
            print("招待コード一覧読み込みエラー: \(error)")
            inviteCodes = [] // 空配列をセット
        }

        isLoading = false
    }

    // MARK: - Firestoreエラーメッセージの取得

    private func getFirestoreErrorMessage(_ error: Error, defaultMessage: String) -> String {
        let nsError = error as NSError

        // Firestoreのエラーかチェック
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 7: // PERMISSION_DENIED
                return "権限がありません"
            case 14: // UNAVAILABLE
                return "サービスが利用できません。しばらくしてからお試しください"
            case 8: // RESOURCE_EXHAUSTED
                return "リクエスト数の上限に達しました"
            case 4: // DEADLINE_EXCEEDED
                return "タイムアウトしました"
            default:
                return defaultMessage
            }
        }

        // ネットワークエラー
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "インターネットに接続されていません"
            case NSURLErrorTimedOut:
                return "接続がタイムアウトしました"
            default:
                return "ネットワークエラーが発生しました"
            }
        }

        return defaultMessage
    }
}

// MARK: - 招待コード行ビュー

struct InviteCodeRow: View {
    let inviteCode: InviteCode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // コード
                Text(inviteCode.code)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                // ステータスバッジ
                if inviteCode.isUsed {
                    Badge(text: "使用済み", color: .gray)
                } else if inviteCode.isExpired {
                    Badge(text: "期限切れ", color: .red)
                } else {
                    Badge(text: "未使用", color: .green)
                }
            }

            // 作成日時
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                Text("作成日: \(formattedDate(inviteCode.createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 有効期限
            if let expiresAt = inviteCode.expiresAt {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text("有効期限: \(formattedDate(expiresAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 使用者
            if let usedBy = inviteCode.usedBy {
                UsedByView(uid: usedBy)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(action: {
                UIPasteboard.general.string = inviteCode.code
            }) {
                Label("コードをコピー", systemImage: "doc.on.doc")
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - 使用者表示ビュー

struct UsedByView: View {
    let uid: String
    @State private var displayName: String = "読み込み中..."

    private let userService = UserService()

    var body: some View {
        HStack {
            Image(systemName: "person.fill")
                .foregroundColor(.secondary)
            Text("使用者: \(displayName)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .task {
            await fetchUserDisplayName()
        }
    }

    private func fetchUserDisplayName() async {
        print("🔍 招待コード使用者の表示名取得: UID=\(uid)")

        do {
            if let user = try await userService.fetchUser(uid: uid) {
                // ニックネームがあればニックネーム、なければメールアドレスを表示
                if let nickname = user.nickname {
                    print("✅ ニックネームで表示: \(nickname)")
                    displayName = nickname
                } else {
                    print("✅ メールアドレスで表示: \(user.email)")
                    displayName = user.email
                }
            } else {
                // ユーザーが見つからない場合はUIDを表示
                print("⚠️ ユーザーが見つからないためUIDを表示: \(uid)")
                displayName = "不明なユーザー (\(uid))"
            }
        } catch {
            // エラーが発生した場合はUIDを表示
            print("❌ 使用者情報取得エラー: \(error.localizedDescription)")
            print("   UID: \(uid)")
            displayName = "エラー (\(uid))"
        }
    }
}

// MARK: - ステータスバッジ

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(8)
    }
}

#Preview {
    AdminInviteCodeView()
        .environmentObject(AuthenticationManager())
}
