//
//  GoogleMapView.swift
//  MatchSpotter
//
//  Created by 千馬拓磨
//

import SwiftUI
import GoogleMaps
import SwiftData
import CoreLocation
import OSLog

/// GoogleMapをUIViewRepresentableでラップしたビュー
struct GoogleMapViewRepresentable: UIViewRepresentable {
    let locations: [Location]
    let sharedPhotos: [SharedPhoto]
    @Binding var selectedLocation: Location?
    @Binding var selectedPhotoId: String?
    @Binding var selectedSharedPhoto: SharedPhoto?

    private static let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "GoogleMapView")

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: 35.6812, longitude: 139.7671, zoom: 12.0)
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        mapView.delegate = context.coordinator

        // マップの設定
        mapView.settings.compassButton = true
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.rotateGestures = true
        mapView.settings.tiltGestures = true

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // 既存のマーカーをクリア
        mapView.clear()

        // 各写真にマーカーを配置（位置情報がある写真のみ）
        var bounds = GMSCoordinateBounds()
        var hasMarkers = false

        // ローカルの写真のマーカーを追加
        if !locations.isEmpty {
            // 位置情報でグループ化（100m以内の写真は同じグループ）
            var photoGroups: [[PhotoData]] = []
            var processedPhotos: Set<ObjectIdentifier> = []

            for location in locations {
            for photo in location.photos {
                // 既に処理済みの写真はスキップ
                if processedPhotos.contains(ObjectIdentifier(photo)) {
                    continue
                }

                guard let photoLat = photo.latitude, let photoLon = photo.longitude else {
                    Self.logger.debug("⚠️ 写真に位置情報なし: \(photo.title ?? "無題")")
                    continue
                }

                let photoLocation = CLLocation(latitude: photoLat, longitude: photoLon)
                var currentGroup: [PhotoData] = [photo]
                processedPhotos.insert(ObjectIdentifier(photo))

                // 同じLocation内の他の写真で100m以内のものをグループ化
                for otherPhoto in location.photos {
                    if processedPhotos.contains(ObjectIdentifier(otherPhoto)) {
                        continue
                    }

                    if let otherLat = otherPhoto.latitude, let otherLon = otherPhoto.longitude {
                        let otherLocation = CLLocation(latitude: otherLat, longitude: otherLon)
                        let distance = photoLocation.distance(from: otherLocation)

                        // 100m以内なら同じグループ
                        if distance <= 100 {
                            currentGroup.append(otherPhoto)
                            processedPhotos.insert(ObjectIdentifier(otherPhoto))
                        }
                    }
                }

                photoGroups.append(currentGroup)
            }
        }

        // グループごとにマーカーを作成
        for group in photoGroups {
            guard let firstPhoto = group.first,
                  let photoLat = firstPhoto.latitude,
                  let photoLon = firstPhoto.longitude,
                  let location = firstPhoto.location else {
                continue
            }

            let coordinate = CLLocationCoordinate2D(latitude: photoLat, longitude: photoLon)

            if group.count == 1 {
                // 1枚のみの場合
                Self.logger.debug("📍 マーカー作成: \(firstPhoto.title ?? "無題") at (\(photoLat), \(photoLon))")
            } else {
                // 複数枚の場合（同じEXIF情報）
                Self.logger.debug("📍 マーカー作成: \(group.count)枚の写真 at (\(photoLat), \(photoLon))")
            }

            let marker = GMSMarker()
            marker.position = coordinate

            if group.count == 1 {
                marker.title = firstPhoto.title ?? location.name
                marker.snippet = location.name
                marker.userData = ["location": location, "photo": firstPhoto]
            } else {
                marker.title = location.name
                marker.snippet = "\(group.count)枚の写真"
                marker.userData = location
            }

            // カスタムマーカーアイコン（カメラアイコン風）
            marker.icon = createCustomMarkerIcon()
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.5) // 中央をアンカーポイントに設定
            marker.map = mapView

            // 境界を拡張
            bounds = bounds.includingCoordinate(marker.position)
            hasMarkers = true
        }

        // 位置情報がない写真がある場合はLocationの座標を使用
        for location in locations {
            let hasPhotoWithLocation = location.photos.contains { $0.latitude != nil && $0.longitude != nil }
            if !hasPhotoWithLocation, !location.photos.isEmpty, let coordinate = location.coordinate {
                let marker = GMSMarker()
                marker.position = coordinate
                marker.title = location.name
                marker.snippet = "\(location.photos.count)枚の写真"
                marker.userData = location

                // カスタムマーカーアイコン（カメラアイコン風）
                marker.icon = createCustomMarkerIcon()
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5) // 中央をアンカーポイントに設定
                marker.map = mapView

                // 境界を拡張
                bounds = bounds.includingCoordinate(marker.position)
                hasMarkers = true
            }
        }
        } // ローカルの写真の処理終了

        // 共有写真のマーカーを追加（位置情報があるもののみ）
        for sharedPhoto in sharedPhotos {
            guard let latitude = sharedPhoto.latitude,
                  let longitude = sharedPhoto.longitude else {
                continue
            }

            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            Self.logger.debug("📍 共有写真マーカー作成: \(sharedPhoto.title) at (\(latitude), \(longitude))")

            let marker = GMSMarker()
            marker.position = coordinate
            marker.title = sharedPhoto.title
            marker.snippet = "共有写真"
            if let locationName = sharedPhoto.locationName {
                marker.snippet = "\(locationName) - 共有写真"
            }
            marker.userData = sharedPhoto

            // 青いカスタムマーカーアイコン（共有写真）
            marker.icon = createCustomMarkerIcon(isShared: true)
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            marker.map = mapView

            // 境界を拡張
            bounds = bounds.includingCoordinate(marker.position)
            hasMarkers = true
        }

        // マーカーがある場合のみカメラを調整
        if hasMarkers {
            let update = GMSCameraUpdate.fit(bounds, withPadding: 50.0)
            mapView.moveCamera(update)
        }
    }

    // カスタムマーカーアイコンを作成（カメラアイコン）
    private func createCustomMarkerIcon(isShared: Bool = false) -> UIImage {
        let size: CGFloat = 44
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))

        return renderer.image { context in
            let center = CGPoint(x: size / 2, y: size / 2)

            // 色を切り替え（ローカル=赤、共有=青）
            let mainColor = isShared ? UIColor.systemBlue : UIColor.systemRed

            // 外側の円（半透明）
            let outerRadius: CGFloat = size / 2
            let outerCircle = UIBezierPath(arcCenter: center, radius: outerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            mainColor.withAlphaComponent(0.3).setFill()
            outerCircle.fill()

            // 内側の円
            let innerRadius: CGFloat = 14 // (28 / 2)
            let innerCircle = UIBezierPath(arcCenter: center, radius: innerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            mainColor.setFill()
            innerCircle.fill()

            // カメラアイコン（白）
            let iconSize: CGFloat = 16
            let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .bold)
            if let cameraIcon = UIImage(systemName: "camera.fill", withConfiguration: config) {
                let iconRect = CGRect(
                    x: center.x - iconSize / 2,
                    y: center.y - iconSize / 2,
                    width: iconSize,
                    height: iconSize
                )
                cameraIcon.withTintColor(.white, renderingMode: .alwaysTemplate)
                    .draw(in: iconRect)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapViewRepresentable

        init(_ parent: GoogleMapViewRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let userData = marker.userData as? [String: Any],
               let location = userData["location"] as? Location,
               let photo = userData["photo"] as? PhotoData {
                parent.selectedLocation = location
                parent.selectedPhotoId = photo.persistentModelID.hashValue.description
                parent.selectedSharedPhoto = nil
            } else if let location = marker.userData as? Location {
                // 写真に位置情報がない場合（フォールバック）
                parent.selectedLocation = location
                parent.selectedPhotoId = nil
                parent.selectedSharedPhoto = nil
            } else if let sharedPhoto = marker.userData as? SharedPhoto {
                // 共有写真がタップされた場合
                parent.selectedSharedPhoto = sharedPhoto
                parent.selectedLocation = nil
                parent.selectedPhotoId = nil
            }
            return true
        }

        func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
            var location: Location?
            if let userData = marker.userData as? [String: Any],
               let loc = userData["location"] as? Location {
                location = loc
            } else if let loc = marker.userData as? Location {
                location = loc
            }

            guard let location = location else { return nil }

            let infoWindow = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 80))
            infoWindow.backgroundColor = .systemBackground
            infoWindow.layer.cornerRadius = 8
            infoWindow.layer.shadowColor = UIColor.black.cgColor
            infoWindow.layer.shadowOpacity = 0.3
            infoWindow.layer.shadowOffset = CGSize(width: 0, height: 2)
            infoWindow.layer.shadowRadius = 4

            let titleLabel = UILabel(frame: CGRect(x: 10, y: 10, width: 180, height: 20))
            titleLabel.text = location.name
            titleLabel.font = .boldSystemFont(ofSize: 16)
            titleLabel.textColor = .label

            let subtitleLabel = UILabel(frame: CGRect(x: 10, y: 35, width: 180, height: 16))
            subtitleLabel.text = "\(location.photos.count)枚の写真"
            subtitleLabel.font = .systemFont(ofSize: 14)
            subtitleLabel.textColor = .secondaryLabel

            let tapLabel = UILabel(frame: CGRect(x: 10, y: 55, width: 180, height: 14))
            tapLabel.text = "タップして詳細を表示"
            tapLabel.font = .systemFont(ofSize: 12)
            tapLabel.textColor = .systemPink

            infoWindow.addSubview(titleLabel)
            infoWindow.addSubview(subtitleLabel)
            infoWindow.addSubview(tapLabel)

            return infoWindow
        }
    }
}

/// Google Maps表示ビュー - 場所をマップ上に表示
struct GoogleMapView: View {
    @Query(sort: \Location.createdAt, order: .reverse) private var locations: [Location]
    private let firebaseManager = FirebaseManager.shared
    @State private var selectedLocation: Location?
    @State private var selectedPhotoId: String?
    @State private var selectedSharedPhoto: SharedPhoto?
    @State private var sharedPhotos: [SharedPhoto] = []

    var body: some View {
        NavigationStack {
            GoogleMapViewRepresentable(
                locations: locations,
                sharedPhotos: sharedPhotos,
                selectedLocation: $selectedLocation,
                selectedPhotoId: $selectedPhotoId,
                selectedSharedPhoto: $selectedSharedPhoto
            )
            .navigationBarHidden(true)
            .ignoresSafeArea(edges: .top)
            .task {
                await fetchSharedPhotos()
            }
            .refreshable {
                await fetchSharedPhotos()
            }
            // ローカル場所選択時に詳細画面をシート表示
            .sheet(item: $selectedLocation) { location in
                NavigationStack {
                    PhotoListView(location: location, filteredPhotoId: selectedPhotoId)
                }
                .presentationDetents([.medium, .large])
            }
            // 共有写真選択時に詳細画面をシート表示
            .sheet(item: $selectedSharedPhoto) { photo in
                SharedPhotoDetailView(photo: photo)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Private Methods

    /// 位置情報付き共有写真を取得
    private func fetchSharedPhotos() async {
        do {
            sharedPhotos = try await firebaseManager.fetchPhotosWithLocation()
        } catch {
            // エラーは無視（ログだけ出力）
            print("共有写真の取得に失敗: \(error.localizedDescription)")
        }
    }
}

#Preview {
    GoogleMapView()
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
