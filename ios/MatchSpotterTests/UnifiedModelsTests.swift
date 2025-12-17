//
//  UnifiedModelsTests.swift
//  MatchSpotterTests
//
//  Unit tests for Unified models
//

import XCTest
@testable import MatchSpotter

final class UnifiedModelsTests: XCTestCase {

    // MARK: - UnifiedPrefecture Tests

    func testUnifiedPrefectureInitialization() {
        let prefecture = UnifiedPrefecture(
            name: "東京都",
            photoCount: 10
        )

        XCTAssertEqual(prefecture.id, "東京都")
        XCTAssertEqual(prefecture.name, "東京都")
        XCTAssertNil(prefecture.localPrefecture)
        XCTAssertEqual(prefecture.photoCount, 10)
        XCTAssertNotNil(prefecture.createdAt)
    }

    func testUnifiedPrefectureDefaultValues() {
        let prefecture = UnifiedPrefecture(name: "大阪府")

        XCTAssertEqual(prefecture.photoCount, 0)
        XCTAssertNotNil(prefecture.createdAt)
    }

    // MARK: - UnifiedLocation Tests

    func testUnifiedLocationInitialization() {
        let location = UnifiedLocation(
            name: "新宿",
            prefectureName: "東京都",
            photoCount: 5,
            latitude: 35.6895,
            longitude: 139.6917
        )

        XCTAssertEqual(location.id, "東京都_新宿")
        XCTAssertEqual(location.name, "新宿")
        XCTAssertEqual(location.prefectureName, "東京都")
        XCTAssertEqual(location.photoCount, 5)
        XCTAssertEqual(location.latitude, 35.6895)
        XCTAssertEqual(location.longitude, 139.6917)
        XCTAssertNotNil(location.createdAt)
    }

    func testUnifiedLocationIDGeneration() {
        let location1 = UnifiedLocation(name: "新宿", prefectureName: "東京都")
        let location2 = UnifiedLocation(name: "新宿", prefectureName: "大阪府")

        // 同じ場所名でも都道府県が違えばIDが異なる
        XCTAssertNotEqual(location1.id, location2.id)
        XCTAssertEqual(location1.id, "東京都_新宿")
        XCTAssertEqual(location2.id, "大阪府_新宿")
    }

    func testUnifiedLocationDefaultValues() {
        let location = UnifiedLocation(name: "渋谷", prefectureName: "東京都")

        XCTAssertNil(location.localLocation)
        XCTAssertEqual(location.photoCount, 0)
        XCTAssertNil(location.latitude)
        XCTAssertNil(location.longitude)
    }

    // MARK: - UnifiedPhoto Tests

    func testUnifiedPhotoLocal_IsLocal() {
        let photoData = PhotoData(imageData: Data())
        let unifiedPhoto = UnifiedPhoto.local(photoData)

        XCTAssertTrue(unifiedPhoto.isLocal)
        XCTAssertNotNil(unifiedPhoto.localPhoto)
        XCTAssertNil(unifiedPhoto.sharedPhoto)
    }

    func testUnifiedPhotoShared_IsNotLocal() {
        let sharedPhoto = SharedPhoto(
            imageURL: "https://example.com/image.jpg",
            title: "Test Photo",
            userId: "user-id"
        )
        let unifiedPhoto = UnifiedPhoto.shared(sharedPhoto)

        XCTAssertFalse(unifiedPhoto.isLocal)
        XCTAssertNil(unifiedPhoto.localPhoto)
        XCTAssertNotNil(unifiedPhoto.sharedPhoto)
    }

    func testUnifiedPhotoLocal_Title() {
        let photoData = PhotoData(
            imageData: Data(),
            title: "Local Photo Title"
        )
        let unifiedPhoto = UnifiedPhoto.local(photoData)

        XCTAssertEqual(unifiedPhoto.title, "Local Photo Title")
    }

    func testUnifiedPhotoShared_Title() {
        let sharedPhoto = SharedPhoto(
            imageURL: "https://example.com/image.jpg",
            title: "Shared Photo Title",
            userId: "user-id"
        )
        let unifiedPhoto = UnifiedPhoto.shared(sharedPhoto)

        XCTAssertEqual(unifiedPhoto.title, "Shared Photo Title")
    }

    func testUnifiedPhotoLocal_Caption() {
        let photoData = PhotoData(
            imageData: Data(),
            caption: "Local Caption"
        )
        let unifiedPhoto = UnifiedPhoto.local(photoData)

        XCTAssertEqual(unifiedPhoto.caption, "Local Caption")
    }

    func testUnifiedPhotoShared_Caption() {
        let sharedPhoto = SharedPhoto(
            imageURL: "https://example.com/image.jpg",
            title: "Test",
            caption: "Shared Caption",
            userId: "user-id"
        )
        let unifiedPhoto = UnifiedPhoto.shared(sharedPhoto)

        XCTAssertEqual(unifiedPhoto.caption, "Shared Caption")
    }

    func testUnifiedPhotoLocal_TakenAt() {
        let date = Date()
        let photoData = PhotoData(
            imageData: Data(),
            takenAt: date
        )
        let unifiedPhoto = UnifiedPhoto.local(photoData)

        XCTAssertEqual(unifiedPhoto.takenAt, date)
    }

    func testUnifiedPhotoShared_TakenAt() {
        let date = Date()
        let sharedPhoto = SharedPhoto(
            imageURL: "https://example.com/image.jpg",
            title: "Test",
            userId: "user-id",
            takenAt: date
        )
        let unifiedPhoto = UnifiedPhoto.shared(sharedPhoto)

        XCTAssertEqual(unifiedPhoto.takenAt, date)
    }

    // MARK: - PlaceGroup Tests

    func testPlaceGroupInitialization() {
        let photo1 = UnifiedPhoto.shared(SharedPhoto(
            imageURL: "https://example.com/1.jpg",
            title: "Test Place",
            userId: "user-id"
        ))
        let photo2 = UnifiedPhoto.shared(SharedPhoto(
            imageURL: "https://example.com/2.jpg",
            title: "Test Place",
            userId: "user-id"
        ))

        let placeGroup = PlaceGroup(
            placeName: "Test Place",
            photos: [photo1, photo2]
        )

        XCTAssertEqual(placeGroup.id, "Test Place")
        XCTAssertEqual(placeGroup.placeName, "Test Place")
        XCTAssertEqual(placeGroup.photos.count, 2)
    }

    func testPlaceGroupPhotoCount() {
        let photos = [
            UnifiedPhoto.local(PhotoData(imageData: Data())),
            UnifiedPhoto.local(PhotoData(imageData: Data())),
            UnifiedPhoto.local(PhotoData(imageData: Data()))
        ]

        let placeGroup = PlaceGroup(placeName: "Test Place", photos: photos)

        XCTAssertEqual(placeGroup.photoCount, 3)
    }

    func testPlaceGroupLatestTakenAt() {
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let date3 = Date(timeIntervalSince1970: 3000)

        let photos = [
            UnifiedPhoto.local(PhotoData(imageData: Data(), takenAt: date1)),
            UnifiedPhoto.local(PhotoData(imageData: Data(), takenAt: date3)),
            UnifiedPhoto.local(PhotoData(imageData: Data(), takenAt: date2))
        ]

        let placeGroup = PlaceGroup(placeName: "Test Place", photos: photos)

        XCTAssertEqual(placeGroup.latestTakenAt, date3)
    }

    func testPlaceGroupLatestTakenAt_EmptyPhotos() {
        let placeGroup = PlaceGroup(placeName: "Test Place", photos: [])

        // 空の場合は現在時刻が返されることを確認
        // 特定のインスタンスと比較するのではなく、現在時刻との差がごく最近であることを検証する
        let timeDifference = Date().timeIntervalSince(placeGroup.latestTakenAt)
        XCTAssertTrue(timeDifference < 1.0, "latestTakenAt should be very recent for empty photos")
    }

    func testPlaceGroupRepresentativePhoto() {
        let photo1 = UnifiedPhoto.local(PhotoData(imageData: Data(), title: "First"))
        let photo2 = UnifiedPhoto.local(PhotoData(imageData: Data(), title: "Second"))

        let placeGroup = PlaceGroup(placeName: "Test Place", photos: [photo1, photo2])

        XCTAssertEqual(placeGroup.representativePhoto?.title, "First")
    }

    func testPlaceGroupRepresentativePhoto_EmptyPhotos() {
        let placeGroup = PlaceGroup(placeName: "Test Place", photos: [])

        XCTAssertNil(placeGroup.representativePhoto)
    }
}
