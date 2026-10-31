//
//  OpticsCalculatorTests.swift
//  FieldSharp Tests
//
//  Abschnitt 21: Akzeptanz-Testfälle
//

import Testing
import Foundation
@testable import SharpStopClone

struct OpticsCalculatorTests {

    // MARK: - Test A: Vollformat, 85 mm, f/1.8, Motivdistanz 2,5 m
    @Test func testA_DepthOfField85mmPortrait() throws {
        let format = SensorFormat.fullFrame
        let f = 85.0
        let N = 1.8
        let s = 2500.0 // mm

        let H = hyperfocalDistance(focalLength: f, aperture: N, sensorFormat: format)
        let limits = depthOfFieldLimits(focalLength: f, aperture: N, distance: s, hyperfocal: H)

        let nearM = limits.near / 1000.0
        let farM = limits.far / 1000.0
        let dofCm = (limits.far - limits.near) / 10.0

        #expect(abs(nearM - 2.46) < 0.02)
        #expect(abs(farM - 2.54) < 0.02)
        #expect(abs(dofCm - 8.7) < 0.5)
        #expect(!limits.farIsInfinity)
    }

    // MARK: - Test B: Vollformat, 24 mm, f/11, Fokus auf Hyperfokaldistanz
    @Test func testB_Hyperfocal24mmLandscape() throws {
        let format = SensorFormat.fullFrame
        let f = 24.0
        let N = 11.0

        let H = hyperfocalDistance(focalLength: f, aperture: N, sensorFormat: format)
        let H_meters = H / 1000.0

        #expect(abs(H_meters - 1.84) < 0.05)

        let limits = depthOfFieldLimits(focalLength: f, aperture: N, distance: H, hyperfocal: H)
        let nearM = limits.near / 1000.0

        #expect(abs(nearM - 0.92) < 0.03)
        #expect(limits.farIsInfinity)
    }

    // MARK: - Test C: Hyperfokal-Tabelle für Vollformat, 24 mm
    @Test func testC_HyperfocalTableValues() throws {
        let format = SensorFormat.fullFrame
        let f = 24.0

        // Vorgaben aus Spezifikation:
        // f/2.8: H 7.2 m, 1/2 H 3.6 m
        let h28 = hyperfocalDistance(focalLength: f, aperture: 2.8, sensorFormat: format) / 1000.0
        #expect(abs(h28 - 7.2) < 0.2)
        #expect(abs((h28 / 2.0) - 3.6) < 0.1)

        // f/4: H 5.0 m, 1/2 H 2.5 m
        let h4 = hyperfocalDistance(focalLength: f, aperture: 4.0, sensorFormat: format) / 1000.0
        #expect(abs(h4 - 5.0) < 0.2)
        #expect(abs((h4 / 2.0) - 2.5) < 0.1)

        // f/5.6: H 3.6 m, 1/2 H 1.8 m
        let h56 = hyperfocalDistance(focalLength: f, aperture: 5.6, sensorFormat: format) / 1000.0
        #expect(abs(h56 - 3.6) < 0.2)
        #expect(abs((h56 / 2.0) - 1.8) < 0.1)

        // f/8: H 2.5 m, 1/2 H 1.3 m
        let h8 = hyperfocalDistance(focalLength: f, aperture: 8.0, sensorFormat: format) / 1000.0
        #expect(abs(h8 - 2.5) < 0.2)
        #expect(abs((h8 / 2.0) - 1.3) < 0.1)

        // f/11: H 1.8 m, 1/2 H 0.92 m
        let h11 = hyperfocalDistance(focalLength: f, aperture: 11.0, sensorFormat: format) / 1000.0
        #expect(abs(h11 - 1.8) < 0.2)
        #expect(abs((h11 / 2.0) - 0.92) < 0.1)

        // f/16: H 1.3 m, 1/2 H 0.64 m
        let h16 = hyperfocalDistance(focalLength: f, aperture: 16.0, sensorFormat: format) / 1000.0
        #expect(abs(h16 - 1.3) < 0.2)
        #expect(abs((h16 / 2.0) - 0.64) < 0.1)

        // f/22: H 0.93 m, 1/2 H 0.47 m
        let h22 = hyperfocalDistance(focalLength: f, aperture: 22.0, sensorFormat: format) / 1000.0
        #expect(abs(h22 - 0.93) < 0.2)
        #expect(abs((h22 / 2.0) - 0.47) < 0.1)
    }

    // MARK: - Test D: Fokus-Stacking für Vollformat, 24 mm, f/8, 0,40 m bis ∞
    @Test func testD_FocusStackingSequence() throws {
        let shots = calculateFocusStack(
            focalLength: 24.0,
            aperture: 8.0,
            sensorFormat: .fullFrame,
            requestedNearM: 0.40,
            requestedFarM: nil,
            overlapFraction: 0.15
        )

        // Referenzergebnis aus Spezifikation: 4 Aufnahmen: 0,47 · 0,70 · 1,4 · 2,5 m
        #expect(shots.count == 4)

        if shots.count == 4 {
            #expect(abs(shots[0].focusDistanceM - 0.47) < 0.03)
            #expect(abs(shots[1].focusDistanceM - 0.70) < 0.05)
            #expect(abs(shots[2].focusDistanceM - 1.38) < 0.08)
            #expect(abs(shots[3].focusDistanceM - 2.52) < 0.08)
            #expect(shots[3].farIsInfinity)
        }
    }

    // MARK: - Test E: Astrofotografie / Sternspuren Vollformat, 33 MP, 14 mm, f/2.8
    @Test func testE_AstroNPFAnd500Rule() throws {
        let format = SensorFormat.fullFrame
        let mp = 33.0
        let f = 14.0
        let N = 2.8

        let width = pixelWidth(sensorMP: mp, sensorWidthMM: format.sensorWidthMM, sensorHeightMM: format.sensorHeightMM)
        let pitch = pixelPitch(sensorWidthMM: format.sensorWidthMM, pixelWidth: width)

        #expect(abs(Double(width) - 7036.0) < 50.0)
        #expect(abs(pitch - 5.12) < 0.05)

        let npf = npfShutterTime(focalLength: f, aperture: N, pixelPitchMicrons: pitch)
        let r500 = npf500Rule(focalLength: f, sensorFormat: format)

        #expect(abs(npf - 18.0) < 0.5)
        #expect(abs(r500 - 35.7) < 0.5)
    }

    // MARK: - Test F: ND-Filter 1/250 s + 10 Stufen
    @Test func testF_NDFilter10Stops() throws {
        let base = 1.0 / 250.0
        let stops = 10

        let calcTime = ndExposureTime(baseTimeSeconds: base, stops: stops)
        let density = opticalDensity(stops: stops)
        let factor = ndFactor(stops: stops)

        #expect(abs(calcTime - 4.096) < 0.01)
        #expect(abs(density - 3.0) < 0.01)
        #expect(abs(factor - 1024.0) < 0.1)
    }

    // MARK: - Test G: Bildfeld Vollformat, 50 mm, Motivdistanz 5,0 m
    @Test func testG_FieldOfView50mm() throws {
        let format = SensorFormat.fullFrame
        let f = 50.0
        let s = 5000.0 // mm

        let w = nearFieldWidth(sensorWidthMM: format.sensorWidthMM, focalLength: f, focusDistanceMM: s) / 1000.0
        let h = nearFieldHeight(sensorHeightMM: format.sensorHeightMM, focalLength: f, focusDistanceMM: s) / 1000.0

        #expect(abs(w - 3.56) < 0.05)
        #expect(abs(h - 2.38) < 0.05)

        let horizDeg = radToDeg(horizontalFOV(sensorWidthMM: format.sensorWidthMM, focalLength: f))
        let vertDeg = radToDeg(verticalFOV(sensorHeightMM: format.sensorHeightMM, focalLength: f))

        #expect(abs(horizDeg - 39.6) < 0.5)
        #expect(abs(vertDeg - 27.0) < 0.5)
    }

    // MARK: - Test H: Astronomische Koordinaten & Einheiten
    @Test func testH_GalacticCenterAndUnits() throws {
        #expect(abs(galacticCenterRA - 266.41683) < 0.001)
        #expect(abs(galacticCenterDec - (-29.00781)) < 0.001)

        let meter = 1.0
        let feet = metersToFeet(meter)
        #expect(abs(feet - 3.2808) < 0.01)
        #expect(abs(feetToMeters(feet) - 1.0) < 0.001)

        let timeFormatted = formattedExposureTime(seconds: 4.1)
        #expect(timeFormatted == "4.1 s")
    }
}
