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

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
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
                try await authManager.signUp(email: email, password: password)
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
        let errorCode = (error as NSError).code
        switch errorCode {
        case 17007: // email already in use
            return "このメールアドレスは既に登録されています"
        case 17008: // invalid email
            return "メールアドレスの形式が正しくありません"
        case 17026: // weak password
            return "パスワードは6文字以上で設定してください"
        case 17020: // network error
            return "ネットワークエラーが発生しました"
        default:
            return error.localizedDescription
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthenticationManager())
}
