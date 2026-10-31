//
//  EquipmentManager.swift
//  FieldSharp (Clean-Room-Nachbau)
//

import Foundation
import Combine

public final class EquipmentManager: ObservableObject {
    @Published public var cameras: [CameraBody] = [] {
        didSet { saveCameras() }
    }
    @Published public var lenses: [Lens] = [] {
        didSet { saveLenses() }
    }
    @Published public var selectedCamera: CameraBody? {
        didSet {
            UserDefaults.standard.set(selectedCamera?.id.uuidString, forKey: "selectedCameraId")
        }
    }
    @Published public var selectedLens: Lens? {
        didSet {
            UserDefaults.standard.set(selectedLens?.id.uuidString, forKey: "selectedLensId")
        }
    }

    private let camerasKey = "saved_cameras_v2"
    private let lensesKey = "saved_lenses_v2"

    public init() {
        loadEquipment()
    }

    private func loadEquipment() {
        // Load Cameras
        if let data = UserDefaults.standard.data(forKey: camerasKey),
           let decoded = try? JSONDecoder().decode([CameraBody].self, from: data),
           !decoded.isEmpty {
            self.cameras = decoded
        } else {
            self.cameras = defaultCameras()
        }

        // Load Lenses
        if let data = UserDefaults.standard.data(forKey: lensesKey),
           let decoded = try? JSONDecoder().decode([Lens].self, from: data),
           !decoded.isEmpty {
            self.lenses = decoded
        } else {
            self.lenses = defaultLenses()
        }

        // Restore selection
        if let savedCamId = UserDefaults.standard.string(forKey: "selectedCameraId"),
           let uuid = UUID(uuidString: savedCamId),
           let found = cameras.first(where: { $0.id == uuid }) {
            self.selectedCamera = found
        } else {
            self.selectedCamera = cameras.first
        }

        if let savedLensId = UserDefaults.standard.string(forKey: "selectedLensId"),
           let uuid = UUID(uuidString: savedLensId),
           let found = lenses.first(where: { $0.id == uuid }) {
            self.selectedLens = found
        } else {
            self.selectedLens = lenses.first
        }
    }

    private func saveCameras() {
        if let data = try? JSONEncoder().encode(cameras) {
            UserDefaults.standard.set(data, forKey: camerasKey)
        }
    }

    private func saveLenses() {
        if let data = try? JSONEncoder().encode(lenses) {
            UserDefaults.standard.set(data, forKey: lensesKey)
        }
    }

    // Default Equipment matching the specification examples
    private func defaultCameras() -> [CameraBody] {
        [
            CameraBody(name: "Full-frame body", sensorFormat: .fullFrame, megapixels: 33.0),
            CameraBody(name: "APS-C body", sensorFormat: .apsc, megapixels: 40.0),
            CameraBody(name: "Micro Four Thirds body", sensorFormat: .microFourThirds, megapixels: 25.0),
            CameraBody(name: "Medium Format 44×33 body", sensorFormat: .mediumFormat44, megapixels: 100.0)
        ]
    }

    private func defaultLenses() -> [Lens] {
        [
            Lens(name: "14 mm f/1.8", isZoom: false, minFocalLengthMM: 14.0, maxFocalLengthMM: 14.0, maxApertureWide: 1.8, minimumFocusDistanceM: 0.20, sensorFormat: .fullFrame),
            Lens(name: "24–70 mm f/2.8", isZoom: true, minFocalLengthMM: 24.0, maxFocalLengthMM: 70.0, maxApertureWide: 2.8, minimumFocusDistanceM: 0.38, sensorFormat: .fullFrame),
            Lens(name: "85 mm f/1.8", isZoom: false, minFocalLengthMM: 85.0, maxFocalLengthMM: 85.0, maxApertureWide: 1.8, minimumFocusDistanceM: 0.80, sensorFormat: .fullFrame),
            Lens(name: "50 mm f/1.4", isZoom: false, minFocalLengthMM: 50.0, maxFocalLengthMM: 50.0, maxApertureWide: 1.4, minimumFocusDistanceM: 0.45, sensorFormat: .fullFrame),
            Lens(name: "70–200 mm f/2.8", isZoom: true, minFocalLengthMM: 70.0, maxFocalLengthMM: 200.0, maxApertureWide: 2.8, minimumFocusDistanceM: 1.20, sensorFormat: .fullFrame)
        ]
    }

    public func addCamera(_ camera: CameraBody) {
        cameras.append(camera)
        if selectedCamera == nil {
            selectedCamera = camera
        }
    }

    public func updateCamera(_ camera: CameraBody) {
        if let idx = cameras.firstIndex(where: { $0.id == camera.id }) {
            cameras[idx] = camera
            if selectedCamera?.id == camera.id {
                selectedCamera = camera
            }
        }
    }

    public func addLens(_ lens: Lens) {
        lenses.append(lens)
        if selectedLens == nil {
            selectedLens = lens
        }
    }

    public func updateLens(_ lens: Lens) {
        if let idx = lenses.firstIndex(where: { $0.id == lens.id }) {
            lenses[idx] = lens
            if selectedLens?.id == lens.id {
                selectedLens = lens
            }
        }
    }

    public func removeCamera(at offsets: IndexSet) {
        cameras.remove(atOffsets: offsets)
        if let sel = selectedCamera, !cameras.contains(where: { $0.id == sel.id }) {
            selectedCamera = cameras.first
        }
    }

    public func removeLens(at offsets: IndexSet) {
        lenses.remove(atOffsets: offsets)
        if let sel = selectedLens, !lenses.contains(where: { $0.id == sel.id }) {
            selectedLens = lenses.first
        }
    }

    public func clampFocalLength(_ fl: Double) -> Double {
        guard let lens = selectedLens else { return max(8.0, min(800.0, fl)) }
        return max(lens.minFocalLengthMM, min(lens.maxFocalLengthMM, fl))
    }

    public func clampAperture(_ ap: Double, focalLength: Double) -> Double {
        guard let lens = selectedLens else { return max(1.0, min(32.0, ap)) }
        let maxAp = lens.maxAperture(at: focalLength)
        return max(maxAp, min(32.0, ap))
    }

    public func clampDistance(_ distM: Double) -> Double {
        guard let lens = selectedLens else { return max(0.1, distM) }
        return max(lens.minimumFocusDistanceM, distM)
    }
}
