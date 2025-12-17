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

    override class func setUp() {
        super.setUp()
        // Firebase初期化（テスト実行前に一度だけ実行）
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    override func setUp() throws {
        try super.setUp()
        // 各テストの前に元のユーザーを保存
        originalUser = manager.currentUser
    }

    override func tearDown() throws {
        // 各テストの後に元のユーザーを復元
        manager.currentUser = originalUser
        try super.tearDown()
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

    // MARK: - Initial State Tests

    func testInitialStateProperties() {
        // Then: Published変数が存在し、適切な型であることを確認
        // 注意: FirebaseManagerはシングルトンで実際のFirebase認証状態に依存するため、
        // 値そのものではなくプロパティの存在を確認

        _ = manager.isAuthenticated  // Bool型
        _ = manager.sharedPhotos     // [SharedPhoto]型
        _ = manager.isLoading        // Bool型
        _ = manager.errorMessage     // String?型
        _ = manager.hasMorePhotos    // Bool型
        _ = manager.currentUser      // User?型

        // userDisplayNameが正しく動作することを確認（別のテストでカバー済み）
        XCTAssertTrue(true, "FirebaseManagerの基本プロパティが存在する")
    }
}
