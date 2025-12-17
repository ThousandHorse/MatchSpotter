//
//  FirebaseManagerTests.swift
//  MatchSpotterTests
//
//  Unit tests for FirebaseManager
//

import XCTest
import FirebaseCore
@testable import MatchSpotter

@MainActor
final class FirebaseManagerTests: XCTestCase {

    private let manager = FirebaseManager.shared
    private var originalUser: User?
    private var originalSharedPhotos: [SharedPhoto] = []
    private var originalIsLoading: Bool = false
    private var originalErrorMessage: String?
    private var originalHasMorePhotos: Bool = false

    override class func setUp() {
        super.setUp()
        // Firebase初期化（テスト実行前に一度だけ実行）
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    override func setUp() {
        super.setUp()
        // 各テストの前に元の状態を保存
        originalUser = manager.currentUser
        originalSharedPhotos = manager.sharedPhotos
        originalIsLoading = manager.isLoading
        originalErrorMessage = manager.errorMessage
        originalHasMorePhotos = manager.hasMorePhotos
    }

    override func tearDown() {
        // 各テストの後に元の状態を復元
        manager.currentUser = originalUser
        manager.sharedPhotos = originalSharedPhotos
        manager.isLoading = originalIsLoading
        manager.errorMessage = originalErrorMessage
        manager.hasMorePhotos = originalHasMorePhotos
        super.tearDown()
    }

    // MARK: - User Display Name Tests

    func testUserDisplayName_WithNickname() async {
        // Given: ユーザーにnicknameが設定されている
        manager.currentUser = User(
            id: "test-id",
            email: "test@example.com",
            displayName: "Display Name",
            nickname: "Nickname"
        )

        // When: userDisplayNameを取得
        let displayName = manager.userDisplayName

        // Then: nicknameが優先される
        XCTAssertEqual(displayName, "Nickname")
    }

    func testUserDisplayName_WithDisplayNameOnly() async {
        // Given: ユーザーにdisplayNameのみ設定されている

        manager.currentUser = User(
            id: "test-id",
            email: "test@example.com",
            displayName: "Display Name",
            nickname: nil
        )

        // When: userDisplayNameを取得
        let displayName = manager.userDisplayName

        // Then: displayNameが使用される
        XCTAssertEqual(displayName, "Display Name")
    }

    func testUserDisplayName_WithEmailOnly() async {
        // Given: ユーザーにemailのみ設定されている

        manager.currentUser = User(
            id: "test-id",
            email: "testuser@example.com",
            displayName: nil,
            nickname: nil
        )

        // When: userDisplayNameを取得
        let displayName = manager.userDisplayName

        // Then: emailの@より前が使用される
        XCTAssertEqual(displayName, "testuser")
    }

    func testUserDisplayName_WithEmptyNickname() async {
        // Given: nicknameが空文字列

        manager.currentUser = User(
            id: "test-id",
            email: "test@example.com",
            displayName: "Display Name",
            nickname: ""
        )

        // When: userDisplayNameを取得
        let displayName = manager.userDisplayName

        // Then: displayNameが使用される
        XCTAssertEqual(displayName, "Display Name")
    }

    func testUserDisplayName_WithEmptyDisplayName() async {
        // Given: displayNameが空文字列

        manager.currentUser = User(
            id: "test-id",
            email: "testuser@example.com",
            displayName: "",
            nickname: nil
        )

        // When: userDisplayNameを取得
        let displayName = manager.userDisplayName

        // Then: emailの@より前が使用される
        XCTAssertEqual(displayName, "testuser")
    }

    func testUserDisplayName_NoCurrentUser() async {
        // Given: currentUserがnil

        manager.currentUser = nil

        // When: userDisplayNameを取得
        let displayName = manager.userDisplayName

        // Then: nilが返される
        XCTAssertNil(displayName)
    }

    // MARK: - Error Tests

    func testFirebaseManagerError_Descriptions() {
        XCTAssertEqual(
            FirebaseManagerError.notAuthenticated.errorDescription,
            "ログインが必要です"
        )
        XCTAssertEqual(
            FirebaseManagerError.photoNotFound.errorDescription,
            "写真が見つかりません"
        )
        XCTAssertEqual(
            FirebaseManagerError.permissionDenied.errorDescription,
            "自分の投稿のみ削除できます"
        )
        XCTAssertEqual(
            FirebaseManagerError.userNotFound.errorDescription,
            "ユーザー情報が見つかりません"
        )
    }

    // MARK: - Property Existence Tests

    func testPublishedPropertiesExist() {
        // FirebaseManagerはシングルトンで実際のFirebase認証状態に依存するため、
        // 具体的な値ではなく、プロパティが正しい型で存在することを確認

        // 型チェック: プロパティにアクセスできることを確認
        let _: Bool = manager.isAuthenticated
        let _: [SharedPhoto] = manager.sharedPhotos
        let _: Bool = manager.isLoading
        let _: String? = manager.errorMessage
        let _: Bool = manager.hasMorePhotos
        let _: User? = manager.currentUser
        let _: String? = manager.userDisplayName

        // プロパティが存在し、アクセス可能であることを確認
        XCTAssertTrue(true, "All FirebaseManager published properties are accessible")
    }
}
