//
//  SensorFormat.swift
//  FieldSharp (Clean-Room-Nachbau)
//
//  Sechs editiergeschützte Grundformate von 1 Zoll bis Mittelformat.
//  CoC = Sensordiagonale / 1500 (nach Spezifikation)
//

import Foundation

public enum SensorFormat: String, CaseIterable, Codable, Sendable, Identifiable {
    case oneInch         = "1\""
    case microFourThirds = "Micro Four Thirds"
    case apsc            = "APS-C"
    case fullFrame       = "Vollformat"
    case mediumFormat44  = "Mittelformat 44×33"
    case mediumFormat645 = "Mittelformat 645"

    public var id: String { rawValue }

    /// Sensorbreite in mm
    public var sensorWidthMM: Double {
        switch self {
        case .oneInch:         return 13.2
        case .microFourThirds: return 17.3
        case .apsc:            return 23.5
        case .fullFrame:       return 36.0
        case .mediumFormat44:  return 43.8
        case .mediumFormat645: return 56.0
        }
    }

    /// Sensorhöhe in mm
    public var sensorHeightMM: Double {
        switch self {
        case .oneInch:         return 8.8
        case .microFourThirds: return 13.0
        case .apsc:            return 15.6
        case .fullFrame:       return 24.0
        case .mediumFormat44:  return 32.9
        case .mediumFormat645: return 41.5
        }
    }

    /// Sensordiagonale in mm: sqrt(width² + height²)
    public var sensorDiagonalMM: Double {
        hypot(sensorWidthMM, sensorHeightMM)
    }

    /// Zerstreuungskreis in mm: Sensordiagonale / 1500
    /// Für Vollformat 36×24 mm ergibt sich exakt c ≈ 0,0288444 mm
    public var circleOfConfusion: Double {
        sensorDiagonalMM / 1500.0
    }

    /// Crop-Faktor relativ zu Vollformat (36×24 mm Diagonale = 43.2666 mm)
    public var cropFactor: Double {
        let fullFrameDiagonal = hypot(36.0, 24.0)
        return fullFrameDiagonal / sensorDiagonalMM
    }

    public var displayName: String {
        switch self {
        case .oneInch:         return "1\" (13,2 × 8,8 mm)"
        case .microFourThirds: return "Micro Four Thirds (17,3 × 13 mm)"
        case .apsc:            return "APS-C (23,5 × 15,6 mm)"
        case .fullFrame:       return "Vollformat (36 × 24 mm)"
        case .mediumFormat44:  return "Mittelformat 44×33 mm"
        case .mediumFormat645: return "Mittelformat 645 (56 × 41,5 mm)"
        }
    }

    public var shortName: String {
        switch self {
        case .oneInch:         return "1 Zoll"
        case .microFourThirds: return "MFT"
        case .apsc:            return "APS-C"
        case .fullFrame:       return "Vollformat"
        case .mediumFormat44:  return "MF 44×33"
        case .mediumFormat645: return "MF 645"
        }
    }
}
