//
//  Lens.swift
//  FieldSharp (Clean-Room-Nachbau)
//

import Foundation

public struct Lens: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID
    public var name: String
    public var isZoom: Bool
    public var minFocalLengthMM: Double
    public var maxFocalLengthMM: Double
    public var maxApertureWide: Double
    public var maxApertureTele: Double?
    public var minimumFocusDistanceM: Double
    public var sensorFormat: SensorFormat
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        isZoom: Bool = false,
        minFocalLengthMM: Double,
        maxFocalLengthMM: Double,
        maxApertureWide: Double,
        maxApertureTele: Double? = nil,
        minimumFocusDistanceM: Double = 0.25,
        sensorFormat: SensorFormat = .fullFrame,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isZoom = isZoom
        self.minFocalLengthMM = minFocalLengthMM
        self.maxFocalLengthMM = maxFocalLengthMM
        self.maxApertureWide = maxApertureWide
        self.maxApertureTele = maxApertureTele ?? maxApertureWide
        self.minimumFocusDistanceM = minimumFocusDistanceM
        self.sensorFormat = sensorFormat
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Convenience initializer for backward compatibility
    public init(
        id: UUID = UUID(),
        make: String,
        model: String,
        focalLengthMM: Double,
        maxAperture: Double,
        minFocusDistanceM: Double = 0.25,
        sensorFormat: SensorFormat = .fullFrame
    ) {
        let fullName = make.isEmpty ? model : "\(make) \(model)"
        self.init(
            id: id,
            name: fullName,
            isZoom: false,
            minFocalLengthMM: focalLengthMM,
            maxFocalLengthMM: focalLengthMM,
            maxApertureWide: maxAperture,
            maxApertureTele: maxAperture,
            minimumFocusDistanceM: minFocusDistanceM,
            sensorFormat: sensorFormat
        )
    }

    /// Naheinstellgrenze in Millimetern
    public var minimumFocusDistanceMM: Double {
        minimumFocusDistanceM * 1000.0
    }

    /// Maximale Blendenöffnung für eine gegebene Brennweite
    public func maxAperture(at focalLength: Double) -> Double {
        guard isZoom, maxFocalLengthMM > minFocalLengthMM, let tele = maxApertureTele else {
            return maxApertureWide
        }
        let t = (focalLength - minFocalLengthMM) / (maxFocalLengthMM - minFocalLengthMM)
        let clamped = max(0.0, min(1.0, t))
        return maxApertureWide + clamped * (tele - maxApertureWide)
    }

    public var focalLengthDisplay: String {
        if isZoom && minFocalLengthMM != maxFocalLengthMM {
            return "\(Int(round(minFocalLengthMM)))–\(Int(round(maxFocalLengthMM))) mm"
        } else {
            return "\(Int(round(minFocalLengthMM))) mm"
        }
    }

    public var apertureDisplay: String {
        if let tele = maxApertureTele, tele != maxApertureWide {
            return "f/\(String(format: "%.1f", maxApertureWide))–\(String(format: "%.1f", tele))"
        } else {
            return "f/\(String(format: "%.1f", maxApertureWide))"
        }
    }

    public var description: String {
        let nearStr: String
        if minimumFocusDistanceM < 1.0 {
            nearStr = "\(Int(round(minimumFocusDistanceM * 100))) cm"
        } else {
            nearStr = "\(String(format: "%.2f", minimumFocusDistanceM)) m"
        }
        return "\(name) · \(focalLengthDisplay) \(apertureDisplay) · Naheinstellgrenze \(nearStr)"
    }

    // Compatibility fields
    public var focalLengthMM: Double {
        minFocalLengthMM
    }

    public var maxAperture: Double {
        maxApertureWide
    }

    public var minFocusDistanceM: Double {
        minimumFocusDistanceM
    }

    public var make: String {
        name.components(separatedBy: " ").first ?? ""
    }

    public var model: String {
        let parts = name.components(separatedBy: " ")
        return parts.dropFirst().joined(separator: " ")
    }
}
