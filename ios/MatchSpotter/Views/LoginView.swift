//
//  LoginView.swift
//  MatchSpotter
//
//  Created by Claude
//

import SwiftUI

/// ログイン・サインアップ画面
struct LoginView: View {
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUpMode = false
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // ロゴ・タイトル
                VStack(spacing: 12) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.pink.gradient)

                    Text("MatchSpotter")
                        .font(.system(size: 32, weight: .bold))

                    Text("写真を共有して思い出を記録")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)

                Spacer()

                // フォーム
                VStack(spacing: 16) {
                    if isSignUpMode {
                        TextField("表示名（任意）", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                    }

                    TextField("メールアドレス", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("パスワード", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUpMode ? .newPassword : .password)

                    if firebaseManager.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        Button {
                            Task {
                                await handleAuthentication()
                            }
                        } label: {
                            Text(isSignUpMode ? "アカウント作成" : "ログイン")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.pink)
                                .cornerRadius(12)
                        }
                        .disabled(email.isEmpty || password.isEmpty)
                    }

                    // モード切り替え
                    Button {
                        isSignUpMode.toggle()
                    } label: {
                        Text(isSignUpMode ? "すでにアカウントをお持ちの方はこちら" : "アカウントをお持ちでない方はこちら")
                            .font(.footnote)
                            .foregroundColor(.blue)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // ゲストログイン
                    Button {
                        Task {
                            await handleAnonymousSignIn()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle")
                            Text("ゲストとして続ける")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(firebaseManager.isLoading)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("エラー", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(firebaseManager.errorMessage ?? "不明なエラーが発生しました")
            }
        }
    }

    private func handleAuthentication() async {
        do {
            if isSignUpMode {
                try await firebaseManager.signUp(
                    email: email,
                    password: password,
                    displayName: displayName.isEmpty ? nil : displayName
                )
            } else {
                try await firebaseManager.signIn(email: email, password: password)
            }
        } catch {
            showError = true
        }
    }

    private func handleAnonymousSignIn() async {
        do {
            try await firebaseManager.signInAnonymously()
        } catch {
            showError = true
        }
    }
}

#Preview {
    LoginView()
}
