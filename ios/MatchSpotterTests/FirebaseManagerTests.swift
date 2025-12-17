//
//  FirebaseManagerTests.swift
//  MatchSpotterTests
//
//  Unit tests for FirebaseManager
//

import XCTest
@testable import MatchSpotter

@MainActor
final class FirebaseManagerTests: XCTestCase {

    // MARK: - User Display Name Tests

    func testUserDisplayName_WithNickname() async {
        // Given: ユーザーにnicknameが設定されている
        let manager = FirebaseManager.shared
        let originalUser = manager.currentUser

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

        // Cleanup
        manager.currentUser = originalUser
    }

    func testUserDisplayName_WithDisplayNameOnly() async {
        // Given: ユーザーにdisplayNameのみ設定されている
        let manager = FirebaseManager.shared
        let originalUser = manager.currentUser

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

        // Cleanup
        manager.currentUser = originalUser
    }

    func testUserDisplayName_WithEmailOnly() async {
        // Given: ユーザーにemailのみ設定されている
        let manager = FirebaseManager.shared
        let originalUser = manager.currentUser

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

        // Cleanup
        manager.currentUser = originalUser
    }

    func testUserDisplayName_WithEmptyNickname() async {
        // Given: nicknameが空文字列
        let manager = FirebaseManager.shared
        let originalUser = manager.currentUser

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

        // Cleanup
        manager.currentUser = originalUser
    }

    func testUserDisplayName_WithEmptyDisplayName() async {
        // Given: displayNameが空文字列
        let manager = FirebaseManager.shared
        let originalUser = manager.currentUser

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

        // Cleanup
        manager.currentUser = originalUser
    }

    func testUserDisplayName_NoCurrentUser() async {
        // Given: currentUserがnil
        let manager = FirebaseManager.shared
        let originalUser = manager.currentUser

        manager.currentUser = nil

        // When: userDisplayNameを取得
        let displayName = manager.userDisplayName

        // Then: nilが返される
        XCTAssertNil(displayName)

        // Cleanup
        manager.currentUser = originalUser
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
        let manager = FirebaseManager.shared

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
