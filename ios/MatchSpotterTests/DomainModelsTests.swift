//
//  DomainModelsTests.swift
//  MatchSpotterTests
//
//  Unit tests for Domain models (Prefecture, Location, PhotoData)
//

import XCTest
import CoreLocation
@testable import MatchSpotter

final class DomainModelsTests: XCTestCase {

    // MARK: - Prefecture Tests

    func testPrefectureInitialization() {
        let prefecture = Prefecture(name: "東京都")

        XCTAssertEqual(prefecture.name, "東京都")
        XCTAssertNotNil(prefecture.createdAt)
        XCTAssertTrue(prefecture.locations.isEmpty)
    }

    func testPrefectureLocationCount() {
        let prefecture = Prefecture(name: "東京都")
        let location1 = Location(name: "新宿")
        let location2 = Location(name: "渋谷")

        prefecture.locations = [location1, location2]

        XCTAssertEqual(prefecture.locationCount, 2)
    }

    func testPrefectureTotalPhotoCount() {
        let prefecture = Prefecture(name: "東京都")
        let location1 = Location(name: "新宿")
        let location2 = Location(name: "渋谷")

        let photo1 = PhotoData(imageData: Data())
        let photo2 = PhotoData(imageData: Data())
        let photo3 = PhotoData(imageData: Data())

        location1.photos = [photo1, photo2]
        location2.photos = [photo3]
        prefecture.locations = [location1, location2]

        XCTAssertEqual(prefecture.totalPhotoCount, 3)
    }

    func testPrefectureTotalPhotoCount_NoPhotos() {
        let prefecture = Prefecture(name: "東京都")
        let location = Location(name: "新宿")

        prefecture.locations = [location]

        XCTAssertEqual(prefecture.totalPhotoCount, 0)
    }

    // MARK: - Location Tests

    func testLocationInitialization() {
        let location = Location(name: "東京駅")

        XCTAssertEqual(location.name, "東京駅")
        XCTAssertNil(location.latitude)
        XCTAssertNil(location.longitude)
        XCTAssertNotNil(location.createdAt)
        XCTAssertTrue(location.photos.isEmpty)
    }

    func testLocationInitializationWithCoordinates() {
        let location = Location(
            name: "東京駅",
            latitude: 35.6812,
            longitude: 139.7671
        )

        XCTAssertEqual(location.name, "東京駅")
        XCTAssertEqual(location.latitude, 35.6812)
        XCTAssertEqual(location.longitude, 139.7671)
    }

    func testLocationCoordinate_WithValidCoordinates() throws {
        let location = Location(
            name: "東京駅",
            latitude: 35.6812,
            longitude: 139.7671
        )

        let coordinate = try XCTUnwrap(location.coordinate)
        XCTAssertEqual(coordinate.latitude, 35.6812, accuracy: 0.0001)
        XCTAssertEqual(coordinate.longitude, 139.7671, accuracy: 0.0001)
    }

    func testLocationCoordinate_WithoutCoordinates() {
        let location = Location(name: "東京駅")

        XCTAssertNil(location.coordinate)
    }

    func testLocationCoordinate_WithPartialCoordinates() {
        let location1 = Location(name: "場所1", latitude: 35.6812, longitude: nil)
        let location2 = Location(name: "場所2", latitude: nil, longitude: 139.7671)

        XCTAssertNil(location1.coordinate)
        XCTAssertNil(location2.coordinate)
    }

    func testLocationTotalPhotoCount() {
        let location = Location(name: "新宿")
        let photo1 = PhotoData(imageData: Data())
        let photo2 = PhotoData(imageData: Data())

        location.photos = [photo1, photo2]

        XCTAssertEqual(location.totalPhotoCount, 2)
    }

    func testLocationTotalPhotoCount_NoPhotos() {
        let location = Location(name: "新宿")

        XCTAssertEqual(location.totalPhotoCount, 0)
    }

    // MARK: - PhotoData Tests

    func testPhotoDataInitialization() {
        let imageData = Data([0x01, 0x02, 0x03])
        let photo = PhotoData(imageData: imageData)

        XCTAssertEqual(photo.imageData, imageData)
        XCTAssertNil(photo.title)
        XCTAssertNil(photo.caption)
        XCTAssertNotNil(photo.takenAt)
        XCTAssertNil(photo.latitude)
        XCTAssertNil(photo.longitude)
        XCTAssertNil(photo.firestoreId)
    }

    func testPhotoDataInitializationWithAllFields() {
        let imageData = Data([0x01, 0x02, 0x03])
        let takenDate = Date()
        let photo = PhotoData(
            imageData: imageData,
            title: "Test Photo",
            caption: "Test Caption",
            takenAt: takenDate,
            latitude: 35.6812,
            longitude: 139.7671,
            firestoreId: "firestore-id-123"
        )

        XCTAssertEqual(photo.imageData, imageData)
        XCTAssertEqual(photo.title, "Test Photo")
        XCTAssertEqual(photo.caption, "Test Caption")
        XCTAssertEqual(photo.takenAt, takenDate)
        XCTAssertEqual(photo.latitude, 35.6812)
        XCTAssertEqual(photo.longitude, 139.7671)
        XCTAssertEqual(photo.firestoreId, "firestore-id-123")
    }

    // MARK: - Relationship Tests

    func testLocationPrefectureRelationship() {
        let prefecture = Prefecture(name: "東京都")
        let location = Location(name: "新宿")

        location.prefecture = prefecture
        prefecture.locations = [location]

        XCTAssertEqual(location.prefecture?.name, "東京都")
        XCTAssertEqual(prefecture.locations.count, 1)
        XCTAssertEqual(prefecture.locations.first?.name, "新宿")
    }

    func testPhotoDataLocationRelationship() {
        let location = Location(name: "新宿")
        let photo = PhotoData(imageData: Data())

        photo.location = location
        location.photos = [photo]

        XCTAssertEqual(photo.location?.name, "新宿")
        XCTAssertEqual(location.photos.count, 1)
    }
}
