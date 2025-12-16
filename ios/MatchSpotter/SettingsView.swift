//
//  SettingsView.swift
//  MatchSpotter
//
//  Created by Claude Code
//

import SwiftUI
import OSLog

/// 設定画面 - 開発用のみ
struct SettingsView: View {
    @AppStorage("useAppleMap") private var useAppleMap = false
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @State private var showProfileEdit = false

    var body: some View {
        NavigationStack {
            Form {
                // ユーザー情報セクション
                Section("ユーザー情報") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.pink)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(firebaseManager.userDisplayName ?? "ユーザー")
                                .font(.headline)

                            if let email = firebaseManager.currentUser?.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)

                    Button {
                        showProfileEdit = true
                    } label: {
                        HStack {
                            Text("プロフィールを編集")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("マップ設定") {
                    Toggle("Apple Mapを使用", isOn: $useAppleMap)

                    Text(useAppleMap ? "Apple Mapを使用中" : "Google Mapを使用中")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text("この設定画面は開発版でのみ表示されます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("開発設定")
            .sheet(isPresented: $showProfileEdit) {
                ProfileEditView()
            }
        }
    }
}

/// プロフィール編集画面
struct ProfileEditView: View {
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var nickname: String = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "ProfileEditView")

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ニックネーム", text: $nickname)
                        .textContentType(.nickname)

                    Text("このニックネームが写真投稿時に表示されます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("プロフィール情報")
                }

                Section {
                    if let email = firebaseManager.currentUser?.email {
                        LabeledContent("メールアドレス", value: email)
                            .foregroundColor(.secondary)
                    }

                    if let userId = firebaseManager.currentUser?.id {
                        LabeledContent("ユーザーID", value: String(userId.prefix(12)) + "...")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                } header: {
                    Text("アカウント情報")
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(isSaving || nickname.isEmpty)
                }
            }
            .onAppear {
                // 現在のニックネームを取得
                nickname = firebaseManager.currentUser?.nickname ?? firebaseManager.currentUser?.displayName ?? ""
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveProfile() async {
        guard let userId = firebaseManager.currentUser?.id else { return }

        isSaving = true

        do {
            // Firestoreのユーザードキュメントを更新
            try await firebaseManager.updateUserProfile(nickname: nickname)

            logger.info("✅ プロフィール更新成功: \(nickname)")
            dismiss()
        } catch {
            logger.error("❌ プロフィール更新失敗: \(error.localizedDescription)")
            errorMessage = "プロフィールの更新に失敗しました"
            showError = true
        }

        isSaving = false
    }
}

#Preview {
    SettingsView()
}
