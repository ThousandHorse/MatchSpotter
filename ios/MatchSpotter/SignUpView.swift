//
//  SignUpView.swift
//  MatchSpotter
//
//  会員登録画面
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var inviteCode = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var nickname = ""
    @State private var isLoading = false
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

                ScrollView {
                    VStack(spacing: 30) {
                        // ヘッダー
                        VStack(spacing: 10) {
                            Image(systemName: "person.badge.plus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.white)
                                .padding(.top, 40)

                            Text("アカウント作成")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)

                            Text("新しいアカウントを作成します")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.bottom, 20)

                        // 登録フォーム
                        VStack(spacing: 16) {
                            // 招待コード入力
                            VStack(alignment: .leading, spacing: 8) {
                                Label("招待コード（必須）", systemImage: "ticket.fill")
                                    .font(.footnote)
                                    .foregroundColor(.white)

                                TextField("招待コードを入力", text: $inviteCode)
                                    .textContentType(.oneTimeCode)
                                    .autocapitalization(.allCharacters)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }

                            // メールアドレス入力
                            VStack(alignment: .leading, spacing: 8) {
                                Label("メールアドレス", systemImage: "envelope.fill")
                                    .font(.footnote)
                                    .foregroundColor(.white)

                                TextField("example@email.com", text: $email)
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
                            }

                            // パスワード入力
                            VStack(alignment: .leading, spacing: 8) {
                                Label("パスワード（6文字以上）", systemImage: "lock.fill")
                                    .font(.footnote)
                                    .foregroundColor(.white)

                                SecureField("パスワードを入力", text: $password)
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }

                            // パスワード確認入力
                            VStack(alignment: .leading, spacing: 8) {
                                Label("パスワード確認", systemImage: "lock.fill")
                                    .font(.footnote)
                                    .foregroundColor(.white)

                                SecureField("パスワードを再入力", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(passwordsMatch ? Color.gray.opacity(0.3) : Color.red, lineWidth: 1)
                                    )

                                if !confirmPassword.isEmpty && !passwordsMatch {
                                    Text("パスワードが一致しません")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            // パスワード強度インジケーター
                            if !password.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("パスワード強度: \(passwordStrengthText)")
                                        .font(.caption)
                                        .foregroundColor(passwordStrengthColor)

                                    ProgressView(value: passwordStrength, total: 3.0)
                                        .tint(passwordStrengthColor)
                                }
                            }

                            // ニックネーム入力（任意）
                            VStack(alignment: .leading, spacing: 8) {
                                Label("ニックネーム（任意）", systemImage: "person.fill")
                                    .font(.footnote)
                                    .foregroundColor(.white)

                                TextField("ニックネームを入力", text: $nickname)
                                    .textContentType(.name)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }

                            // 登録ボタン
                            Button(action: handleSignUp) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                } else {
                                    Text("登録")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                }
                            }
                            .background(isFormValid ? Color.green : Color.gray)
                            .cornerRadius(10)
                            .disabled(isLoading || !isFormValid)
                            .padding(.top, 10)

                            // 利用規約
                            Text("登録することで、利用規約とプライバシーポリシーに同意したことになります")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.top, 5)
                        }
                        .padding(.horizontal, 30)

                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("エラー", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - バリデーション

    private var passwordsMatch: Bool {
        password == confirmPassword
    }

    private var isFormValid: Bool {
        !inviteCode.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        password.count >= 6 &&
        passwordsMatch
    }

    // MARK: - パスワード強度チェック

    private var passwordStrength: Double {
        var strength = 0.0
        if password.count >= 6 { strength += 1.0 }
        if password.count >= 10 { strength += 1.0 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil &&
           password.rangeOfCharacter(from: .letters) != nil {
            strength += 1.0
        }
        return strength
    }

    private var passwordStrengthText: String {
        switch passwordStrength {
        case 0..<1.5: return "弱い"
        case 1.5..<2.5: return "普通"
        default: return "強い"
        }
    }

    private var passwordStrengthColor: Color {
        switch passwordStrength {
        case 0..<1.5: return .red
        case 1.5..<2.5: return .orange
        default: return .green
        }
    }

    // MARK: - 登録処理

    private func handleSignUp() {
        isLoading = true

        Task {
            do {
                let nicknameValue = nickname.isEmpty ? nil : nickname
                try await authManager.signUp(
                    email: email,
                    password: password,
                    inviteCode: inviteCode,
                    nickname: nicknameValue
                )
                dismiss()
            } catch {
                alertMessage = getErrorMessage(error)
                showAlert = true
            }
            isLoading = false
        }
    }

    // MARK: - エラーメッセージの取得

    private func getErrorMessage(_ error: Error) -> String {
        // 招待コードエラー
        if let inviteError = error as? InviteError {
            return inviteError.localizedDescription
        }

        let nsError = error as NSError

        // Firestoreエラー
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 7: // PERMISSION_DENIED
                return "招待コードの検証に失敗しました。Firestoreのセキュリティルールを確認してください。"
            case 14: // UNAVAILABLE
                return "サービスが利用できません。しばらくしてからお試しください"
            default:
                return "データベースエラーが発生しました"
            }
        }

        // FirebaseAuthのエラーかチェック
        guard nsError.domain == "FIRAuthErrorDomain" else {
            return "エラーが発生しました"
        }

        switch nsError.code {
        case 17007: // ERROR_EMAIL_ALREADY_IN_USE
            return "このメールアドレスは既に登録されています"
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
            return "アカウント作成に失敗しました（エラーコード: \(nsError.code)）"
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthenticationManager())
}
