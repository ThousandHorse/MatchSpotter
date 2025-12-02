//
//  LoginView.swift
//  MatchSpotter
//
//  ログイン画面
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showSignUp = false
    @State private var showPasswordReset = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer()

                    // アプリアイコン
                    Image(systemName: "camera.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.white)
                        .padding(.bottom, 20)

                    // アプリ名
                    Text("MatchSpotter")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    Text("写真スポットを見つけよう")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()

                    // ログインフォーム
                    VStack(spacing: 16) {
                        // メールアドレス入力
                        TextField("メールアドレス", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        // パスワード入力
                        SecureField("パスワード", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        // パスワードを忘れた場合
                        HStack {
                            Spacer()
                            Button("パスワードを忘れた場合") {
                                showPasswordReset = true
                            }
                            .font(.footnote)
                            .foregroundColor(.white)
                        }

                        // ログインボタン
                        Button(action: handleLogin) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            } else {
                                Text("ログイン")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                        }
                        .background(Color.blue)
                        .cornerRadius(10)
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                        .opacity((isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)

                        // 新規登録ボタン
                        Button(action: {
                            showSignUp = true
                        }) {
                            Text("新規アカウント作成")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 30)

                    Spacer()
                }
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showPasswordReset) {
                PasswordResetView()
            }
            .alert("エラー", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - ログイン処理

    private func handleLogin() {
        isLoading = true

        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                alertMessage = getErrorMessage(error)
                showAlert = true
            }
            isLoading = false
        }
    }

    // MARK: - エラーメッセージの取得

    private func getErrorMessage(_ error: Error) -> String {
        let errorCode = (error as NSError).code
        switch errorCode {
        case 17008, 17009: // wrong password or invalid credential
            return "メールアドレスまたはパスワードが正しくありません"
        case 17011: // user not found
            return "このメールアドレスは登録されていません"
        case 17020: // network error
            return "ネットワークエラーが発生しました"
        default:
            return error.localizedDescription
        }
    }
}

// MARK: - パスワードリセット画面

struct PasswordResetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var email = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("登録されているメールアドレスを入力してください。パスワードリセットリンクを送信します。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()

                TextField("メールアドレス", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)

                Button(action: handlePasswordReset) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("送信")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(email.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(isLoading || email.isEmpty)

                Spacer()
            }
            .navigationTitle("パスワードリセット")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    if alertTitle == "送信完了" {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func handlePasswordReset() {
        isLoading = true

        Task {
            do {
                try await authManager.resetPassword(email: email)
                alertTitle = "送信完了"
                alertMessage = "パスワードリセットリンクを送信しました。メールをご確認ください。"
                showAlert = true
            } catch {
                alertTitle = "エラー"
                alertMessage = error.localizedDescription
                showAlert = true
            }
            isLoading = false
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
}
