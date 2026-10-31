//
//  OpticsCalculator.swift
//  FieldSharp (Clean-Room-Nachbau)
//
//  Reine mathematische Berechnungs-Engine ohne UI-Abhängigkeiten.
//  Optik, Schärfentiefe, Hyperfokale Distanz, Fokus-Stacking,
//  Astrofotografie (NPF, 500er-Regel, Meeus-Astronomie), ND-Filter,
//  Bildfeld (Thin-Lens-Nahfokus) und PDF-Export.
//

import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Circle of Confusion (Zerstreuungskreis)
/// Standard-Regel: c = Sensordiagonale / 1500
/// Für Vollformat 36×24 mm: c ≈ 0,0288444 mm
public func circleOfConfusion(sensorWidthMM: Double, sensorHeightMM: Double) -> Double {
    let diagonal = hypot(sensorWidthMM, sensorHeightMM)
    return diagonal / 1500.0
}

public func circleOfConfusion(for format: SensorFormat) -> Double {
    circleOfConfusion(sensorWidthMM: format.sensorWidthMM, sensorHeightMM: format.sensorHeightMM)
}

// MARK: - Hyperfokale Distanz
/// H = f² / (N · c) + f
/// - f: Brennweite in mm
/// - N: Blendenzahl
/// - c: Zerstreuungskreis in mm
/// Ergebnis: H in mm
public func hyperfocalDistance(focalLength f: Double, aperture N: Double, circleOfConfusion c: Double) -> Double {
    guard N > 0, c > 0 else { return 0 }
    return (f * f) / (N * c) + f
}

public func hyperfocalDistance(focalLength f: Double, aperture N: Double, sensorFormat: SensorFormat) -> Double {
    hyperfocalDistance(focalLength: f, aperture: N, circleOfConfusion: circleOfConfusion(for: sensorFormat))
}

// MARK: - Schärfentiefe (Exakte Formeln)
/// Dn = s · (H - f) / (H + s - 2f)
/// Df = s · (H - f) / (H - s)    // nur für s < H, sonst ∞
/// Bei s = H ist Dn = H/2 und Df = ∞
public func depthOfFieldLimits(
    focalLength f: Double,
    aperture N: Double,
    distance s: Double,
    hyperfocal H: Double
) -> (near: Double, far: Double, farIsInfinity: Bool) {
    guard s > 0, H > 0 else {
        return (0, 0, false)
    }

    let numerator = s * (H - f)
    let denomNear = H + s - 2.0 * f
    let denomFar = H - s

    let nearLimit: Double
    if denomNear <= 0 {
        nearLimit = max(f, s / 2.0)
    } else {
        nearLimit = max(0.001, numerator / denomNear)
    }

    let farLimit: Double
    let farIsInfinity: Bool
    if denomFar <= 1e-6 {
        farLimit = Double.infinity
        farIsInfinity = true
    } else {
        let calcFar = numerator / denomFar
        if calcFar <= 0 || calcFar.isInfinite || calcFar > 100_000_000 {
            farLimit = Double.infinity
            farIsInfinity = true
        } else {
            farLimit = calcFar
            farIsInfinity = false
        }
    }

    return (nearLimit, farLimit, farIsInfinity)
}

public func depthOfField(
    focalLength f: Double,
    aperture N: Double,
    distance s: Double,
    sensorFormat: SensorFormat
) -> (near: Double, far: Double, farIsInfinity: Bool) {
    let H = hyperfocalDistance(focalLength: f, aperture: N, sensorFormat: sensorFormat)
    return depthOfFieldLimits(focalLength: f, aperture: N, distance: s, hyperfocal: H)
}

public func depthOfFieldComponents(
    focalLength f: Double,
    aperture N: Double,
    distance s: Double,
    sensorFormat: SensorFormat
) -> (near: Double, far: Double, farIsInfinity: Bool, frontDOF: Double, rearDOF: Double, totalDOF: Double) {
    let H = hyperfocalDistance(focalLength: f, aperture: N, sensorFormat: sensorFormat)
    let limits = depthOfFieldLimits(focalLength: f, aperture: N, distance: s, hyperfocal: H)

    let front = max(0.0, s - limits.near)
    let rear: Double
    let total: Double

    if limits.farIsInfinity {
        rear = Double.infinity
        total = Double.infinity
    } else {
        rear = max(0.0, limits.far - s)
        total = max(0.0, limits.far - limits.near)
    }

    return (limits.near, limits.far, limits.farIsInfinity, front, rear, total)
}

// MARK: - Fokus-Stacking Planer
public struct StackShot: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID
    public var index: Int
    public var focusDistanceM: Double
    public var nearLimitM: Double
    public var farLimitM: Double? // nil = infinity
    public var completed: Bool

    public init(id: UUID = UUID(), index: Int, focusDistanceM: Double, nearLimitM: Double, farLimitM: Double?, completed: Bool = false) {
        self.id = id
        self.index = index
        self.focusDistanceM = focusDistanceM
        self.nearLimitM = nearLimitM
        self.farLimitM = farLimitM
        self.completed = completed
    }

    public var farIsInfinity: Bool {
        farLimitM == nil
    }
}

public struct FocusStackPlan: Identifiable, Codable, Sendable {
    public var id: UUID
    public var cameraName: String
    public var sensorFormat: SensorFormat
    public var focalLengthMM: Double
    public var aperture: Double
    public var requestedNearM: Double
    public var requestedFarM: Double? // nil = infinity
    public var overlapFraction: Double
    public var shots: [StackShot]
    public var createdAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        cameraName: String,
        sensorFormat: SensorFormat,
        focalLengthMM: Double,
        aperture: Double,
        requestedNearM: Double,
        requestedFarM: Double?,
        overlapFraction: Double = 0.15,
        shots: [StackShot],
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.cameraName = cameraName
        self.sensorFormat = sensorFormat
        self.focalLengthMM = focalLengthMM
        self.aperture = aperture
        self.requestedNearM = requestedNearM
        self.requestedFarM = requestedFarM
        self.overlapFraction = overlapFraction
        self.shots = shots
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    public var completedCount: Int {
        shots.filter { $0.completed }.count
    }

    public var totalCount: Int {
        shots.count
    }

    public var isFullyCompleted: Bool {
        totalCount > 0 && completedCount == totalCount
    }
}

/// Exakter Stacking-Planungsalgorithmus:
/// Für eine gewünschte Nahkante n < H - f:
/// s = n · (H - 2f) / (H - f - n)
/// nextNear = far_i - overlap · (far_i - near_i)
public func calculateFocusStack(
    focalLength f: Double,
    aperture N: Double,
    sensorFormat: SensorFormat,
    requestedNearM: Double,
    requestedFarM: Double? = nil,
    overlapFraction: Double = 0.15,
    maxShots: Int = 100
) -> [StackShot] {
    let H = hyperfocalDistance(focalLength: f, aperture: N, sensorFormat: sensorFormat)
    let requestedNearMM = requestedNearM * 1000.0
    let requestedFarMM = requestedFarM.map { $0 * 1000.0 }
    let targetIsInfinity = (requestedFarM == nil)

    var shots: [StackShot] = []
    var currentNear = requestedNearMM
    var iteration = 0

    while iteration < maxShots {
        let denom = H - f - currentNear
        if denom <= 1e-4 {
            break
        }

        let s = currentNear * (H - 2.0 * f) / denom
        guard s > 0, s.isFinite else { break }

        if s >= H || (targetIsInfinity && (currentNear >= H / 2.0)) {
            let hShot = StackShot(
                index: iteration + 1,
                focusDistanceM: H / 1000.0,
                nearLimitM: (H / 2.0) / 1000.0,
                farLimitM: nil,
                completed: false
            )
            shots.append(hShot)
            break
        }

        let limits = depthOfFieldLimits(focalLength: f, aperture: N, distance: s, hyperfocal: H)
        let nearM = limits.near / 1000.0
        let farM: Double? = limits.farIsInfinity ? nil : (limits.far / 1000.0)

        shots.append(StackShot(
            index: iteration + 1,
            focusDistanceM: s / 1000.0,
            nearLimitM: nearM,
            farLimitM: farM,
            completed: false
        ))

        if limits.farIsInfinity {
            break
        }

        if let reqFar = requestedFarMM, limits.far >= reqFar - 1.0 {
            break
        }

        let dofRange = limits.far - limits.near
        let nextNear = limits.far - overlapFraction * dofRange

        if targetIsInfinity && nextNear >= (H / 2.0) {
            let hyperM = H / 1000.0
            let hShot = StackShot(
                index: iteration + 2,
                focusDistanceM: hyperM,
                nearLimitM: (H / 2.0) / 1000.0,
                farLimitM: nil,
                completed: false
            )
            shots.append(hShot)
            break
        }

        if nextNear <= currentNear + 1e-4 {
            break
        }

        currentNear = nextNear
        iteration += 1
    }

    if targetIsInfinity && !(shots.last?.farIsInfinity ?? false) {
        let hyperM = H / 1000.0
        let hShot = StackShot(
            index: shots.count + 1,
            focusDistanceM: hyperM,
            nearLimitM: (H / 2.0) / 1000.0,
            farLimitM: nil,
            completed: false
        )
        shots.append(hShot)
    }

    return shots.enumerated().map { (idx, shot) in
        StackShot(
            id: shot.id,
            index: idx + 1,
            focusDistanceM: shot.focusDistanceM,
            nearLimitM: shot.nearLimitM,
            farLimitM: shot.farLimitM,
            completed: shot.completed
        )
    }
}

// MARK: - NPF & 500er-Regel (Astrofotografie)
/// Vereinfachte NPF-Formel: tNPF = (35 · N + 30 · p) / f
/// - N: Blendenzahl
/// - p: Pixelpitch in µm
/// - f: reale Brennweite in mm
/// Ergebnis: maximale Verschlusszeit in Sekunden
public func npfShutterTime(focalLength f: Double, aperture N: Double, pixelPitchMicrons p: Double) -> Double {
    guard f > 0 else { return 0 }
    return (35.0 * N + 30.0 * p) / f
}

/// 500er-Regel: t500 = 500 / (f · cropFactor)
public func npf500Rule(focalLength f: Double, sensorFormat: SensorFormat) -> Double {
    guard f > 0 else { return 0 }
    return 500.0 / (f * sensorFormat.cropFactor)
}

/// Pixelbreite und Pixelpitch aus Megapixeln
public func pixelWidth(sensorMP: Double, sensorWidthMM: Double, sensorHeightMM: Double) -> Int {
    let r = sensorWidthMM / sensorHeightMM
    let P = sensorMP * 1_000_000.0
    return Int(round(sqrt(P * r)))
}

public func pixelPitch(sensorWidthMM: Double, pixelWidth: Int) -> Double {
    guard pixelWidth > 0 else { return 0 }
    return (sensorWidthMM / Double(pixelWidth)) * 1000.0
}

// MARK: - ND-Filter
/// newTime = baseTime · 2^stops
public func ndExposureTime(baseTimeSeconds: Double, stops: Int) -> Double {
    baseTimeSeconds * pow(2.0, Double(stops))
}

/// Optische Dichte = 0,3 · stops
public func opticalDensity(stops: Int) -> Double {
    0.3 * Double(stops)
}

/// ND-Faktor = 2^stops
public func ndFactor(stops: Int) -> Double {
    pow(2.0, Double(stops))
}

// MARK: - Bildfeld (Field of View)
/// Fernbereich-Bildwinkel
public func horizontalFOV(sensorWidthMM: Double, focalLength f: Double) -> Double {
    guard f > 0 else { return 0 }
    return 2.0 * atan(sensorWidthMM / (2.0 * f))
}

public func verticalFOV(sensorHeightMM: Double, focalLength f: Double) -> Double {
    guard f > 0 else { return 0 }
    return 2.0 * atan(sensorHeightMM / (2.0 * f))
}

public func diagonalFOV(sensorWidthMM: Double, sensorHeightMM: Double, focalLength f: Double) -> Double {
    guard f > 0 else { return 0 }
    let diag = hypot(sensorWidthMM, sensorHeightMM)
    return 2.0 * atan(diag / (2.0 * f))
}

/// Dünne-Linsen-Korrektur für Nahbereich:
/// fieldWidth = sensorWidth · (s - f) / f
/// (s und f in derselben Einheit mm)
public func nearFieldWidth(sensorWidthMM: Double, focalLength f: Double, focusDistanceMM s: Double) -> Double {
    guard f > 0, s > f else { return 0 }
    return sensorWidthMM * (s - f) / f
}

public func nearFieldHeight(sensorHeightMM: Double, focalLength f: Double, focusDistanceMM s: Double) -> Double {
    guard f > 0, s > f else { return 0 }
    return sensorHeightMM * (s - f) / f
}

// MARK: - Astronomie Engine
/// Galaktisches Zentrum: RA = 266,41683°, Dec = -29,00781°
public let galacticCenterRA: Double = 266.41683
public let galacticCenterDec: Double = -29.00781

public func degToRad(_ deg: Double) -> Double {
    deg * .pi / 180.0
}

public func radToDeg(_ rad: Double) -> Double {
    rad * 180.0 / .pi
}

public func normalizeAngle(_ angle: Double) -> Double {
    var a = angle.truncatingRemainder(dividingBy: 2.0 * .pi)
    if a < 0 { a += 2.0 * .pi }
    return a
}

public func normalizeDegrees(_ deg: Double) -> Double {
    var d = deg.truncatingRemainder(dividingBy: 360.0)
    if d < 0 { d += 360.0 }
    return d
}

/// Julianisches Datum für ein Date (UTC)
public func julianDate(for date: Date) -> Double {
    let timeInterval = date.timeIntervalSince1970
    return 2440587.5 + (timeInterval / 86400.0)
}

/// Greenwich Mean Sidereal Time in Grad [0, 360)
public func greenwichMeanSiderealTime(for date: Date) -> Double {
    let jd = julianDate(for: date)
    let d = jd - 2451545.0
    var gmst = 280.46061837 + 360.98564736629 * d
    gmst = normalizeDegrees(gmst)
    return gmst
}

/// Lokale Sternzeit (LST) in Radiant [0, 2π)
public func localSiderealTime(for date: Date, longitude: Double) -> Double {
    let gmst = greenwichMeanSiderealTime(for: date)
    let lstDeg = normalizeDegrees(gmst + longitude)
    return degToRad(lstDeg)
}

/// Sonnenhöhe in Grad für ein Date und Standort
public func solarAltitude(date: Date, latitude: Double, longitude: Double) -> Double {
    let jd = julianDate(for: date)
    let d = jd - 2451545.0

    let g = degToRad(normalizeDegrees(357.529 + 0.98560028 * d))
    let q = degToRad(normalizeDegrees(280.459 + 0.98564736 * d))
    let lambda = degToRad(normalizeDegrees(radToDeg(q) + 1.915 * sin(g) + 0.020 * sin(2.0 * g)))

    let eps = degToRad(23.439 - 0.00000036 * d)

    let sinDec = sin(eps) * sin(lambda)
    let dec = asin(sinDec)
    let cosDec = cos(dec)
    let ra = atan2(cos(eps) * sin(lambda), cos(lambda))

    let lst = localSiderealTime(for: date, longitude: longitude)
    let ha = lst - ra

    let latRad = degToRad(latitude)
    let sinAlt = sin(latRad) * sin(dec) + cos(latRad) * cosDec * cos(ha)
    return radToDeg(asin(max(-1.0, min(1.0, sinAlt))))
}

/// Galaktisches Zentrum Höhe & Azimut in Grad
public func galacticCenterPosition(date: Date, latitude: Double, longitude: Double) -> (altitude: Double, azimuth: Double) {
    let lst = localSiderealTime(for: date, longitude: longitude)
    let raRad = degToRad(galacticCenterRA)
    let decRad = degToRad(galacticCenterDec)
    let ha = lst - raRad

    let latRad = degToRad(latitude)
    let sinAlt = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(ha)
    let altRad = asin(max(-1.0, min(1.0, sinAlt)))

    let cosAlt = cos(altRad)
    var azRad: Double = 0
    if cosAlt > 1e-6 {
        let cosAz = (sin(decRad) - sin(latRad) * sinAlt) / (cos(latRad) * cosAlt)
        let sinAz = -cos(decRad) * sin(ha) / cosAlt
        azRad = atan2(sinAz, cosAz)
    }
    let azDeg = normalizeDegrees(radToDeg(azRad))
    return (radToDeg(altRad), azDeg)
}

/// 8-teilige Windrose (N, NO, O, SO, S, SW, W, NW)
public func compassDirection8(azimuthDeg: Double) -> String {
    let d = normalizeDegrees(azimuthDeg)
    let directions = ["N", "NO", "O", "SO", "S", "SW", "W", "NW"]
    let rawIdx = Int(round(d / 45.0)) % 8
    let index = (rawIdx + 8) % 8
    return directions[index]
}

/// Mondphase & Beleuchteter Anteil (0-100%) sowie Mondhöhe
public func moonDetails(date: Date, latitude: Double, longitude: Double) -> (altitude: Double, illuminationPercent: Double) {
    let jd = julianDate(for: date)
    let d = jd - 2451545.0

    let T = d / 36525.0
    let D = degToRad(normalizeDegrees(297.8501921 + 445267.1114034 * T))
    let M = degToRad(normalizeDegrees(357.5291092 + 35999.0502909 * T))
    let Mprime = degToRad(normalizeDegrees(134.9633964 + 477198.8675055 * T))

    let phaseAngle = degToRad(180.0) - D - degToRad(6.289 * sin(Mprime) - 1.274 * sin(2.0 * D - Mprime) - 0.658 * sin(2.0 * D) - 0.214 * sin(2.0 * Mprime) - 0.11 * sin(D))
    let k = (1.0 + cos(phaseAngle)) / 2.0
    let illumination = max(0.0, min(100.0, k * 100.0))

    let Lprime = degToRad(normalizeDegrees(218.3164477 + 481267.881281 * T + 6.289 * sin(Mprime)))
    let sinDec = sin(degToRad(23.439)) * sin(Lprime)
    let dec = asin(sinDec)
    let ra = atan2(cos(degToRad(23.439)) * sin(Lprime), cos(Lprime))

    let lst = localSiderealTime(for: date, longitude: longitude)
    let ha = lst - ra
    let latRad = degToRad(latitude)
    let sinAlt = sin(latRad) * sin(dec) + cos(latRad) * cos(dec) * cos(ha)
    let altDeg = radToDeg(asin(max(-1.0, min(1.0, sinAlt))))

    return (altDeg, illumination)
}

/// Ergebnis der Sichtbarkeitsanalyse für eine Nacht
public struct MilkyWayNightPlan: Identifiable, Sendable {
    public var id = UUID()
    public var date: Date
    public var windowStart: Date?
    public var windowEnd: Date?
    public var maxCoreAltitude: Double
    public var peakDirection: String
    public var moonIllumination: Double
    public var moonInterference: Double
    public var score: Double
    public var isVisible: Bool {
        windowStart != nil && windowEnd != nil && (windowEnd!.timeIntervalSince(windowStart!) >= 600)
    }

    public var windowDurationMinutes: Double {
        guard let s = windowStart, let e = windowEnd, e > s else { return 0 }
        return e.timeIntervalSince(s) / 60.0
    }
}

/// Analysiert eine Nacht (von 18:00 bis 06:00 Ortszeit) auf Kernsichtbarkeit:
/// Sonne <= -18° UND Kern >= 10°
public func analyzeMilkyWayNight(
    nightDate: Date,
    latitude: Double,
    longitude: Double,
    timeZone: TimeZone = .current
) -> MilkyWayNightPlan {
    var calendar = Calendar.current
    calendar.timeZone = timeZone

    let startOfDay = calendar.startOfDay(for: nightDate)
    guard let duskEstimate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: startOfDay),
          let dawnEstimate = calendar.date(byAdding: .hour, value: 12, to: duskEstimate) else {
        return MilkyWayNightPlan(
            date: nightDate,
            windowStart: nil,
            windowEnd: nil,
            maxCoreAltitude: 0,
            peakDirection: "S",
            moonIllumination: 0,
            moonInterference: 1.0,
            score: 0
        )
    }

    var visibleSegments: [(Date, Double, Double, Double)] = []
    var maxCoreAlt: Double = -90.0
    var peakAzimuth: Double = 180.0
    var moonIllum: Double = 0.0

    var current = duskEstimate
    while current <= dawnEstimate {
        let sunAlt = solarAltitude(date: current, latitude: latitude, longitude: longitude)
        let corePos = galacticCenterPosition(date: current, latitude: latitude, longitude: longitude)
        let moonInfo = moonDetails(date: current, latitude: latitude, longitude: longitude)

        moonIllum = moonInfo.illuminationPercent

        if corePos.altitude > maxCoreAlt {
            maxCoreAlt = corePos.altitude
            peakAzimuth = corePos.azimuth
        }

        if sunAlt <= -18.0 && corePos.altitude >= 10.0 {
            visibleSegments.append((current, corePos.altitude, corePos.azimuth, moonInfo.altitude))
        }

        guard let next = calendar.date(byAdding: .minute, value: 5, to: current) else { break }
        current = next
    }

    var winStart: Date? = nil
    var winEnd: Date? = nil
    var moonInterference: Double = 0.0

    if let first = visibleSegments.first, let last = visibleSegments.last {
        winStart = first.0
        winEnd = last.0

        let moonUpCount = visibleSegments.filter { $0.3 > 0 }.count
        let fractionMoonUp = Double(moonUpCount) / Double(visibleSegments.count)
        moonInterference = fractionMoonUp * (moonIllum / 100.0)
    }

    let durationMins = (winStart != nil && winEnd != nil) ? (winEnd!.timeIntervalSince(winStart!) / 60.0) : 0.0
    let normDuration = min(1.0, max(0.0, durationMins / 360.0))
    let normAlt = min(1.0, max(0.0, maxCoreAlt / 45.0))
    let score = (winStart != nil) ? (0.55 * normDuration + 0.25 * normAlt + 0.20 * (1.0 - moonInterference)) : 0.0

    return MilkyWayNightPlan(
        date: nightDate,
        windowStart: winStart,
        windowEnd: winEnd,
        maxCoreAltitude: maxCoreAlt,
        peakDirection: compassDirection8(azimuthDeg: peakAzimuth),
        moonIllumination: moonIllum,
        moonInterference: moonInterference,
        score: max(0.0, min(1.0, score))
    )
}

/// Berechnet die 3 besten Nächte der kommenden 30 Tage
public func bestNightsNext30Days(
    startDate: Date,
    latitude: Double,
    longitude: Double,
    timeZone: TimeZone = .current
) -> [MilkyWayNightPlan] {
    var calendar = Calendar.current
    calendar.timeZone = timeZone

    var plans: [MilkyWayNightPlan] = []
    for dayOffset in 0..<30 {
        if let night = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
            let plan = analyzeMilkyWayNight(nightDate: night, latitude: latitude, longitude: longitude, timeZone: timeZone)
            if plan.isVisible {
                plans.append(plan)
            }
        }
    }

    plans.sort { $0.score > $1.score }
    return Array(plans.prefix(3))
}

// MARK: - Datenmodelle für Orte & Nacht-Logbuch
public struct Place: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var timeZoneIdentifier: String
    public var isBuiltIn: Bool

    public init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double, timeZoneIdentifier: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
        self.isBuiltIn = isBuiltIn
    }

    public var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    public static let builtInPlaces: [Place] = [
        Place(name: "Sternenpark Rhön (Deutschland)", latitude: 50.45, longitude: 10.02, timeZoneIdentifier: "Europe/Berlin", isBuiltIn: true),
        Place(name: "Sternenpark Westhavelland (Deutschland)", latitude: 52.68, longitude: 12.35, timeZoneIdentifier: "Europe/Berlin", isBuiltIn: true),
        Place(name: "Nationalpark Eifel (Deutschland)", latitude: 50.58, longitude: 6.42, timeZoneIdentifier: "Europe/Berlin", isBuiltIn: true),
        Place(name: "Roque de los Muchachos (La Palma, ES)", latitude: 28.75, longitude: -17.88, timeZoneIdentifier: "Atlantic/Canary", isBuiltIn: true),
        Place(name: "Death Valley National Park (USA)", latitude: 36.53, longitude: -116.93, timeZoneIdentifier: "America/Los_Angeles", isBuiltIn: true),
        Place(name: "Jasper National Park (Kanada)", latitude: 52.87, longitude: -117.95, timeZoneIdentifier: "America/Edmonton", isBuiltIn: true),
        Place(name: "Aoraki Mackenzie Dark Sky Reserve (NZ)", latitude: -43.73, longitude: 170.10, timeZoneIdentifier: "Pacific/Auckland", isBuiltIn: true),
        Place(name: "Atacama-Wüste (Chile)", latitude: -23.86, longitude: -69.13, timeZoneIdentifier: "America/Santiago", isBuiltIn: true)
    ]
}

public struct NightLogEntry: Identifiable, Codable, Sendable {
    public var id: UUID
    public var localNightDate: Date
    public var placeName: String
    public var latitude: Double
    public var longitude: Double
    public var timeZoneIdentifier: String
    public var coreWindowStart: Date?
    public var coreWindowEnd: Date?
    public var moonIllumination: Double
    public var direction: String
    public var note: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        localNightDate: Date,
        placeName: String,
        latitude: Double,
        longitude: Double,
        timeZoneIdentifier: String,
        coreWindowStart: Date?,
        coreWindowEnd: Date?,
        moonIllumination: Double,
        direction: String,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.localNightDate = localNightDate
        self.placeName = placeName
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
        self.coreWindowStart = coreWindowStart
        self.coreWindowEnd = coreWindowEnd
        self.moonIllumination = moonIllumination
        self.direction = direction
        self.note = note
        self.createdAt = createdAt
    }
}

// MARK: - Einheiten & Formatierung
public let meterToFeet: Double = 3.280839895
public let feetToMeter: Double = 0.3048

public func metersToFeet(_ meters: Double) -> Double {
    meters * meterToFeet
}

public func feetToMeters(_ feet: Double) -> Double {
    feet * feetToMeter
}

public func formattedDistance(_ meters: Double, useImperial: Bool) -> String {
    if meters.isInfinite {
        return "∞"
    }

    if useImperial {
        let feet = metersToFeet(meters)
        if feet >= 1000 {
            return String(format: "%.0f ft", feet)
        } else if feet >= 100 {
            return String(format: "%.0f ft", feet)
        } else if feet >= 1.0 {
            let totalInches = round(feet * 12.0)
            let ft = Int(totalInches / 12.0)
            let inRem = Int(totalInches) % 12
            if inRem == 0 {
                return "\(ft) ft"
            }
            return "\(ft) ft \(inRem) in"
        } else {
            let inches = round(feet * 12.0 * 10.0) / 10.0
            return "\(inches) in"
        }
    } else {
        if meters >= 100 {
            return String(format: "%.0f m", meters)
        } else if meters >= 1.0 {
            return String(format: "%.2f m", meters)
        } else if meters >= 0.01 {
            let cm = round(meters * 1000.0) / 10.0
            if cm == floor(cm) {
                return "\(Int(cm)) cm"
            }
            return String(format: "%.1f cm", cm)
        } else {
            return String(format: "%.1f mm", meters * 1000.0)
        }
    }
}

public func formattedExposureTime(seconds: Double) -> String {
    guard seconds > 0 else { return "0 s" }

    if seconds < 0.99 {
        let recip = round(1.0 / seconds)
        if recip >= 2 {
            return "1/\(Int(recip)) s"
        } else {
            return String(format: "%.2f s", seconds)
        }
    } else if seconds < 60.0 {
        return String(format: "%.1f s", seconds)
    } else if seconds < 3600.0 {
        let min = Int(seconds / 60.0)
        let sec = Int(seconds.truncatingRemainder(dividingBy: 60.0))
        if sec == 0 {
            return "\(min)m"
        }
        return "\(min)m \(sec)s"
    } else if seconds < 86400.0 {
        let h = Int(seconds / 3600.0)
        let min = Int((seconds.truncatingRemainder(dividingBy: 3600.0)) / 60.0)
        return "\(h)h \(min)m"
    } else {
        let d = Int(seconds / 86400.0)
        let h = Int((seconds.truncatingRemainder(dividingBy: 86400.0)) / 3600.0)
        return "\(d)d \(h)h"
    }
}

// MARK: - PDF Generator für Hyperfokal-Karte
#if canImport(UIKit)
public enum HyperfocalPDFGenerator {
    public static func generatePDF(
        camera: CameraBody,
        lens: Lens,
        focalLengthMM: Double,
        useImperial: Bool
    ) -> Data {
        let pageWidth: CGFloat = 595.2 // A4 @ 72 dpi
        let pageHeight: CGFloat = 841.8
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()
            let cg = context.cgContext

            // Dunkler Hintergrund
            cg.setFillColor(red: 0.043, green: 0.047, blue: 0.063, alpha: 1.0)
            cg.fill(pageRect)

            // Karte Container
            let cardRect = CGRect(x: 36, y: 36, width: pageWidth - 72, height: pageHeight - 72)
            cg.setFillColor(red: 0.09, green: 0.09, blue: 0.106, alpha: 1.0)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 18)
            cardPath.fill()

            cg.setStrokeColor(red: 0.22, green: 0.23, blue: 0.26, alpha: 1.0)
            cg.setLineWidth(1.0)
            cardPath.stroke()

            // Header Text
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor(red: 0.94, green: 0.69, blue: 0.24, alpha: 1.0)
            ]
            let titleString = "HYPERFOKAL-KARTE"
            titleString.draw(at: CGPoint(x: 60, y: 60), withAttributes: titleAttributes)

            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor(red: 0.92, green: 0.93, blue: 0.94, alpha: 1.0)
            ]
            let lensInfo = "\(lens.name) · \(Int(round(focalLengthMM))) mm · \(camera.sensorFormat.displayName)"
            lensInfo.draw(at: CGPoint(x: 60, y: 90), withAttributes: subtitleAttributes)

            let bodyInfo = "\(camera.name) · Zerstreuungskreis: \(String(format: "%.4f", camera.circleOfConfusionMM)) mm"
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor(red: 0.59, green: 0.61, blue: 0.65, alpha: 1.0)
            ]
            bodyInfo.draw(at: CGPoint(x: 60, y: 110), withAttributes: bodyAttributes)

            // Tabellen-Header
            let tableTop: CGFloat = 145
            let col1X: CGFloat = 70
            let col2X: CGFloat = 220
            let col3X: CGFloat = 380

            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor(red: 0.59, green: 0.61, blue: 0.65, alpha: 1.0)
            ]
            "BLENDE".draw(at: CGPoint(x: col1X, y: tableTop), withAttributes: headerAttrs)
            (useImperial ? "H (ft)" : "H (m)").draw(at: CGPoint(x: col2X, y: tableTop), withAttributes: headerAttrs)
            (useImperial ? "½ H (ft)" : "½ H (m)").draw(at: CGPoint(x: col3X, y: tableTop), withAttributes: headerAttrs)

            // Trennlinie
            cg.setStrokeColor(red: 0.22, green: 0.23, blue: 0.26, alpha: 1.0)
            cg.strokeLineSegments(between: [
                CGPoint(x: 60, y: tableTop + 20),
                CGPoint(x: pageWidth - 60, y: tableTop + 20)
            ])

            // Volle Blendenstufen
            let standardApertures: [Double] = [1.4, 1.8, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0]
            let validApertures = standardApertures.filter { $0 >= lens.maxAperture(at: focalLengthMM) - 0.05 }

            var rowY = tableTop + 30
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor(red: 0.92, green: 0.93, blue: 0.94, alpha: 1.0)
            ]
            let amberRowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor(red: 0.94, green: 0.69, blue: 0.24, alpha: 1.0)
            ]

            for ap in validApertures {
                let H_mm = hyperfocalDistance(focalLength: focalLengthMM, aperture: ap, circleOfConfusion: camera.circleOfConfusionMM)
                let H_m = H_mm / 1000.0
                let halfH_m = H_m / 2.0

                let apStr = ap == floor(ap) ? "f/\(Int(ap))" : String(format: "f/%.1f", ap)
                let hStr = useImperial ? String(format: "%.1f ft", metersToFeet(H_m)) : String(format: "%.2f m", H_m)
                let halfHStr = useImperial ? String(format: "%.1f ft", metersToFeet(halfH_m)) : String(format: "%.2f m", halfH_m)

                apStr.draw(at: CGPoint(x: col1X, y: rowY), withAttributes: amberRowAttrs)
                hStr.draw(at: CGPoint(x: col2X, y: rowY), withAttributes: rowAttrs)
                halfHStr.draw(at: CGPoint(x: col3X, y: rowY), withAttributes: rowAttrs)

                rowY += 28
            }

            // Fußnote / Hinweis
            let noteY = rowY + 30
            let noteAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor(red: 0.59, green: 0.61, blue: 0.65, alpha: 1.0)
            ]
            let noteText = "Auf H fokussieren: alles von ungefähr ½H bis unendlich liegt im akzeptablen Schärfebereich.\nErstellt mit FieldSharp · Offline und privat."
            let noteRect = CGRect(x: 60, y: noteY, width: pageWidth - 120, height: 60)
            noteText.draw(in: noteRect, withAttributes: noteAttrs)
        }
    }
}
#endif
