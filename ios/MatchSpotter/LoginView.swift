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
        let nsError = error as NSError

        // FirebaseAuthのエラーかチェック
        guard nsError.domain == "FIRAuthErrorDomain" else {
            return "エラーが発生しました"
        }

        switch nsError.code {
        case 17007: // ERROR_EMAIL_ALREADY_IN_USE
            return "このメールアドレスは既に使用されています"
        case 17008: // ERROR_INVALID_EMAIL
            return "メールアドレスの形式が正しくありません"
        case 17009: // ERROR_WRONG_PASSWORD
            return "パスワードが正しくありません"
        case 17010: // ERROR_TOO_MANY_REQUESTS
            return "リクエストが多すぎます。しばらくしてからお試しください"
        case 17011: // ERROR_USER_NOT_FOUND
            return "このメールアドレスは登録されていません"
        case 17012: // ERROR_ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL
            return "このアカウントは別の方法で登録されています"
        case 17020: // ERROR_NETWORK_ERROR
            return "ネットワークエラーが発生しました"
        case 17026: // ERROR_WEAK_PASSWORD
            return "パスワードは6文字以上で設定してください"
        case 17999: // ERROR_INVALID_CREDENTIAL
            return "認証情報が無効です"
        case 17995: // ERROR_MISSING_EMAIL
            return "メールアドレスを入力してください"
        case 17993: // ERROR_USER_DISABLED
            return "このアカウントは無効化されています"
        case 17014: // ERROR_USER_TOKEN_EXPIRED
            return "セッションが期限切れです。再度ログインしてください"
        default:
            return "ログインに失敗しました（エラーコード: \(nsError.code)）"
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
                alertMessage = getPasswordResetErrorMessage(error)
                showAlert = true
            }
            isLoading = false
        }
    }

    private func getPasswordResetErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError

        // FirebaseAuthのエラーかチェック
        guard nsError.domain == "FIRAuthErrorDomain" else {
            return "エラーが発生しました"
        }

        switch nsError.code {
        case 17008: // ERROR_INVALID_EMAIL
            return "メールアドレスの形式が正しくありません"
        case 17011: // ERROR_USER_NOT_FOUND
            return "このメールアドレスは登録されていません"
        case 17020: // ERROR_NETWORK_ERROR
            return "ネットワークエラーが発生しました"
        case 17010: // ERROR_TOO_MANY_REQUESTS
            return "リクエストが多すぎます。しばらくしてからお試しください"
        case 17995: // ERROR_MISSING_EMAIL
            return "メールアドレスを入力してください"
        default:
            return "パスワードリセットメールの送信に失敗しました"
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
}
