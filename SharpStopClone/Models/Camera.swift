//
//  Camera.swift
//  FieldSharp (Clean-Room-Nachbau)
//

import Foundation

public struct CameraBody: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID
    public var name: String
    public var sensorFormat: SensorFormat
    public var megapixels: Double
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        sensorFormat: SensorFormat = .fullFrame,
        megapixels: Double = 33.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.sensorFormat = sensorFormat
        self.megapixels = megapixels
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Convenience initializer for backward compatibility
    public init(id: UUID = UUID(), make: String, model: String, sensorFormat: SensorFormat = .fullFrame, pixelPitchMicrons: Double? = nil) {
        let fullName = make.isEmpty ? model : "\(make) \(model)"
        // If pixelPitch was given, derive approximate MP
        var mp = 33.0
        if let pitch = pixelPitchMicrons, pitch > 0 {
            let widthPx = (sensorFormat.sensorWidthMM / (pitch / 1000.0))
            let heightPx = (sensorFormat.sensorHeightMM / (pitch / 1000.0))
            mp = round((widthPx * heightPx) / 1_000_000.0)
        }
        self.init(id: id, name: fullName, sensorFormat: sensorFormat, megapixels: max(1.0, mp))
    }

    public var circleOfConfusionMM: Double {
        sensorFormat.circleOfConfusion
    }

    /// Berechneter Pixel-Abstand in µm
    public var pixelPitchMicrons: Double {
        let r = sensorFormat.sensorWidthMM / sensorFormat.sensorHeightMM
        let pTotal = megapixels * 1_000_000.0
        let widthPx = sqrt(pTotal * r)
        return (sensorFormat.sensorWidthMM / widthPx) * 1000.0
    }

    public var pixelWidth: Int {
        let r = sensorFormat.sensorWidthMM / sensorFormat.sensorHeightMM
        let pTotal = megapixels * 1_000_000.0
        return Int(round(sqrt(pTotal * r)))
    }

    public var description: String {
        "\(name) · \(sensorFormat.shortName) · \(Int(round(megapixels))) MP"
    }

    // Compatibility fields
    public var make: String {
        name.components(separatedBy: " ").first ?? ""
    }

    public var model: String {
        let parts = name.components(separatedBy: " ")
        return parts.dropFirst().joined(separator: " ")
    }
}

public typealias Camera = CameraBody
