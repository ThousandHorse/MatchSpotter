//
//  FirebaseModelsTests.swift
//  MatchSpotterTests
//
//  Unit tests for Firebase models
//

import XCTest
@testable import MatchSpotter

final class FirebaseModelsTests: XCTestCase {

    // MARK: - User Model Tests

    func testUserInitialization() {
        let user = User(
            id: "test-user-id",
            email: "test@example.com",
            displayName: "Test User",
            nickname: "Tester"
        )

        XCTAssertEqual(user.id, "test-user-id")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.nickname, "Tester")
        XCTAssertNotNil(user.createdAt)
    }

    func testUserWithOptionalFields() {
        let user1 = User(
            email: "test@example.com",
            displayName: "Test User",
            nickname: "Tester"
        )

        XCTAssertEqual(user1.email, "test@example.com")
        XCTAssertEqual(user1.displayName, "Test User")
        XCTAssertEqual(user1.nickname, "Tester")
        XCTAssertNil(user1.photoURL)

        let user2 = User(
            email: "test2@example.com"
        )

        XCTAssertEqual(user2.email, "test2@example.com")
        XCTAssertNil(user2.displayName)
        XCTAssertNil(user2.nickname)
    }

    // MARK: - SharedPhoto Model Tests

    func testSharedPhotoInitialization() {
        let photo = SharedPhoto(
            id: "photo-id",
            imageURL: "https://example.com/image.jpg",
            title: "Test Photo",
            caption: "Test Caption",
            userId: "user-id",
            userName: "Test User"
        )

        XCTAssertEqual(photo.id, "photo-id")
        XCTAssertEqual(photo.imageURL, "https://example.com/image.jpg")
        XCTAssertEqual(photo.title, "Test Photo")
        XCTAssertEqual(photo.caption, "Test Caption")
        XCTAssertEqual(photo.userId, "user-id")
        XCTAssertEqual(photo.userName, "Test User")
        XCTAssertEqual(photo.likes, 0)
        XCTAssertTrue(photo.likedBy.isEmpty)
    }

    func testSharedPhotoWithLocation() {
        let photo = SharedPhoto(
            imageURL: "https://example.com/image.jpg",
            title: "Test Photo",
            latitude: 35.6762,
            longitude: 139.6503,
            locationName: "東京",
            prefectureName: "東京都",
            userId: "user-id"
        )

        XCTAssertEqual(photo.latitude, 35.6762)
        XCTAssertEqual(photo.longitude, 139.6503)
        XCTAssertTrue(photo.hasLocation)
        XCTAssertEqual(photo.locationName, "東京")
        XCTAssertEqual(photo.prefectureName, "東京都")
    }

    func testSharedPhotoWithoutLocation() {
        let photo = SharedPhoto(
            imageURL: "https://example.com/image.jpg",
            title: "Test Photo",
            userId: "user-id"
        )

        XCTAssertNil(photo.latitude)
        XCTAssertNil(photo.longitude)
        XCTAssertFalse(photo.hasLocation)
    }

    func testSharedPhotoWithAllFields() {
        let photo = SharedPhoto(
            id: "photo-id",
            imageURL: "https://example.com/image.jpg",
            thumbnailURL: "https://example.com/thumb.jpg",
            title: "Test Photo",
            caption: "Test Caption",
            latitude: 35.6762,
            longitude: 139.6503,
            locationName: "東京",
            prefectureName: "東京都",
            userId: "user-id",
            userName: "Test User",
            likes: 10,
            likedBy: ["user1", "user2"]
        )

        XCTAssertEqual(photo.id, "photo-id")
        XCTAssertEqual(photo.imageURL, "https://example.com/image.jpg")
        XCTAssertEqual(photo.thumbnailURL, "https://example.com/thumb.jpg")
        XCTAssertEqual(photo.title, "Test Photo")
        XCTAssertEqual(photo.caption, "Test Caption")
        XCTAssertEqual(photo.latitude, 35.6762)
        XCTAssertEqual(photo.longitude, 139.6503)
        XCTAssertTrue(photo.hasLocation)
        XCTAssertEqual(photo.locationName, "東京")
        XCTAssertEqual(photo.prefectureName, "東京都")
        XCTAssertEqual(photo.userId, "user-id")
        XCTAssertEqual(photo.userName, "Test User")
        XCTAssertEqual(photo.likes, 10)
        XCTAssertEqual(photo.likedBy, ["user1", "user2"])
    }

    // MARK: - PhotoFilter Tests

    func testPhotoFilterEquality() {
        XCTAssertEqual(PhotoFilter.all, PhotoFilter.all)
        XCTAssertEqual(PhotoFilter.myPhotos, PhotoFilter.myPhotos)
        XCTAssertEqual(PhotoFilter.prefecture("東京都"), PhotoFilter.prefecture("東京都"))
        XCTAssertEqual(PhotoFilter.location("新宿"), PhotoFilter.location("新宿"))
        XCTAssertEqual(PhotoFilter.recent, PhotoFilter.recent)

        XCTAssertNotEqual(PhotoFilter.all, PhotoFilter.myPhotos)
        XCTAssertNotEqual(PhotoFilter.prefecture("東京都"), PhotoFilter.prefecture("大阪府"))
        XCTAssertNotEqual(PhotoFilter.location("新宿"), PhotoFilter.location("渋谷"))
    }
}
