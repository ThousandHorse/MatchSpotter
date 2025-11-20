//
//  AddPhotoSpotView.swift
//  MatchSpotter
//
//  Created by 千馬拓磨 on 2025/10/27.
//

import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation
import CoreLocationUI
import ImageIO

/// スポット追加ビュー - 写真とGPS情報から新しい撮影スポットを登録
struct AddPhotoSpotView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var spotName = ""
    @State private var caption = ""
    @State private var isProcessingLocation = false
    @State private var detectedLocation: CLLocation?
    @State private var locationManager = LocationManager()
    @State private var locationName = ""

    var body: some View {
        NavigationView {
            Form {
                Section("写真を選択") {
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        if let selectedImageData,
                           let uiImage = UIImage(data: selectedImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(10)
                        } else {
                            Label("写真を選択", systemImage: "photo")
                                .foregroundColor(.pink)
                        }
                    }
                }
                
                Section("スポット情報") {
                    TextField("スポット名（必須）", text: $spotName)
                        .textContentType(.name)

                    TextField("スポット説明（任意）", text: $caption)

                    if (detectedLocation ?? locationManager.currentLocation) != nil {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("📍 位置情報")
                                .font(.headline)
                            if !locationName.isEmpty {
                                Text(locationName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            } else {
                                Text("場所を取得中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        LocationButton(.currentLocation) {
                            Task {
                                locationManager.requestLocation()
                                // 現在地取得後に場所名を取得
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                if let location = locationManager.currentLocation {
                                    await updateLocationName(from: location)
                                }
                            }
                        }
                        .labelStyle(.iconOnly)
                        .foregroundColor(.white)
                        .tint(.pink)
                    }
                }
                
                if isProcessingLocation {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("写真から位置情報を取得中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

            }
            .navigationTitle("新しいスポット")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        addPhotoSpot()
                    }
                    .disabled(!canAddSpot)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let newValue {
                        await loadSelectedPhoto(newValue)
                    }
                }
            }
        }
    }

    private var canAddSpot: Bool {
        !spotName.isEmpty &&
        selectedImageData != nil &&
        (detectedLocation != nil || locationManager.currentLocation != nil)
    }

    // 選択した写真を読み込み、EXIFから位置情報を抽出
    private func loadSelectedPhoto(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                selectedImageData = data

                // 写真のEXIFデータから位置情報を抽出を試行
                isProcessingLocation = true
                if let location = await extractLocationFromPhoto(data) {
                    detectedLocation = location
                    // 場所名を設定
                    await updateLocationName(from: location)
                }
                isProcessingLocation = false
            }
        } catch {
            print("写真の読み込みに失敗: \(error)")
            isProcessingLocation = false
        }
    }

    // EXIFデータから位置情報を抽出
    private func extractLocationFromPhoto(_ imageData: Data) async -> CLLocation? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let gpsInfo = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            return nil
        }
        
        guard let latitude = gpsInfo[kCGImagePropertyGPSLatitude as String] as? Double,
              let longitude = gpsInfo[kCGImagePropertyGPSLongitude as String] as? Double,
              let latitudeRef = gpsInfo[kCGImagePropertyGPSLatitudeRef as String] as? String,
              let longitudeRef = gpsInfo[kCGImagePropertyGPSLongitudeRef as String] as? String else {
            return nil
        }
        
        let finalLatitude = latitudeRef == "S" ? -latitude : latitude
        let finalLongitude = longitudeRef == "W" ? -longitude : longitude
        
        return CLLocation(latitude: finalLatitude, longitude: finalLongitude)
    }

    // 座標から地名を取得（逆ジオコーディング）
    private func reverseGeocode(_ location: CLLocation) async -> CLPlacemark? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            return placemarks.first
        } catch {
            print("逆ジオコーディングに失敗: \(error)")
            return nil
        }
    }

    // 場所名を更新
    private func updateLocationName(from location: CLLocation) async {
        if let placemark = await reverseGeocode(location) {
            var components: [String] = []

            // 優先順位1: お店・施設名（name）
            if let name = placemark.name,
               !name.isEmpty,
               // 住所っぽい文字列は除外（数字で始まるものなど）
               !name.hasPrefix(placemark.thoroughfare ?? ""),
               !name.contains("丁目"),
               !name.contains("番地") {
                locationName = name
                return
            }

            // 優先順位2: 地区や建物名
            if let subLocality = placemark.subLocality {
                components.append(subLocality)
            }
            if let thoroughfare = placemark.thoroughfare {
                components.append(thoroughfare)
            }

            // 優先順位3: 市区町村
            if components.isEmpty, let locality = placemark.locality {
                components.append(locality)
            }

            // 優先順位4: 都道府県
            if components.isEmpty, let administrativeArea = placemark.administrativeArea {
                components.append(administrativeArea)
            }

            locationName = components.joined(separator: " ")

            if locationName.isEmpty {
                locationName = "不明な場所"
            }
        }
    }

    // スポットをデータベースに追加
    private func addPhotoSpot() {
        guard let imageData = selectedImageData else { return }
        
        let location = detectedLocation ?? locationManager.currentLocation
        guard let location = location else { return }
        
        let newSpot = PhotoSpot(
            name: spotName,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        let photoData = PhotoData(
            imageData: imageData,
            caption: caption.isEmpty ? nil : caption
        )
        photoData.photoSpot = newSpot
        newSpot.photos.append(photoData)
        
        modelContext.insert(newSpot)
        modelContext.insert(photoData)
        
        dismiss()
    }
}

/// 位置情報マネージャー - 現在地の取得を管理
@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var currentLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.first
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置情報の取得に失敗: \(error)")
    }
}

#Preview {
    AddPhotoSpotView()
        .modelContainer(for: [PhotoSpot.self, PhotoData.self], inMemory: true)
}
