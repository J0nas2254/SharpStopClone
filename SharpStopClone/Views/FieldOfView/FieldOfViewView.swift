//
//  FieldOfViewView.swift
//  FieldSharp (Clean-Room-Nachbau)
//
//  Tab 5: Bildfeld & Bildwinkel (Thin-Lens Nahfokus & 1,75 m Silhouette)
//

import SwiftUI

public struct FieldOfViewView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var equipment: EquipmentManager

    private var camera: CameraBody {
        equipment.selectedCamera ?? equipment.cameras.first ?? CameraBody(name: "Standard", sensorFormat: .fullFrame)
    }

    private var lens: Lens {
        equipment.selectedLens ?? equipment.lenses.first ?? Lens(name: "Standard", isZoom: false, minFocalLengthMM: 50, maxFocalLengthMM: 50, maxApertureWide: 1.8, sensorFormat: .fullFrame)
    }

    private var focalLength: Double {
        equipment.clampFocalLength(settings.focalLength)
    }

    private var distanceM: Double {
        equipment.clampDistance(settings.subjectDistance)
    }

    private var distanceMM: Double {
        distanceM * 1000.0
    }

    // Bildwinkel (Grad)
    private var horizAOVdeg: Double {
        radToDeg(horizontalFOV(sensorWidthMM: camera.sensorFormat.sensorWidthMM, focalLength: focalLength))
    }

    private var vertAOVdeg: Double {
        radToDeg(verticalFOV(sensorHeightMM: camera.sensorFormat.sensorHeightMM, focalLength: focalLength))
    }

    private var diagAOVdeg: Double {
        radToDeg(diagonalFOV(sensorWidthMM: camera.sensorFormat.sensorWidthMM, sensorHeightMM: camera.sensorFormat.sensorHeightMM, focalLength: focalLength))
    }

    // Reales Bildfeld bei Fokusdistanz (Meter) mit Dünne-Linsen-Korrektur:
    // field = sensor * (s - f) / f
    private var fieldWidthM: Double {
        nearFieldWidth(sensorWidthMM: camera.sensorFormat.sensorWidthMM, focalLength: focalLength, focusDistanceMM: distanceMM) / 1000.0
    }

    private var fieldHeightM: Double {
        nearFieldHeight(sensorHeightMM: camera.sensorFormat.sensorHeightMM, focalLength: focalLength, focusDistanceMM: distanceMM) / 1000.0
    }

    private var dynamicSentence: String {
        let distStr = settings.formattedDistance(distanceM)
        let wStr = settings.formattedDistance(fieldWidthM)
        let hStr = settings.formattedDistance(fieldHeightM)
        return "Bei \(distStr) erfasst du ein Feld von \(wStr) × \(hStr) (Horizontal \(Int(round(horizAOVdeg)))°, Vertikal \(Int(round(vertAOVdeg)))°)."
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - A. Ergebnis-Karte oben
                resultCard

                // MARK: - B. Parameter-Steuerung
                parametersCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppSettings.appBackground.ignoresSafeArea())
    }

    // MARK: - A. Ergebnis-Karte
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppSettings.accentAmber)
                    .frame(width: 4, height: 48)

                Text(dynamicSentence)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppSettings.primaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Visueller Rahmen mit 1,75 m Personensilhouette
            FieldFrameGraphicView(
                fieldWidthM: fieldWidthM,
                fieldHeightM: fieldHeightM
            )
            .frame(height: 160)
            .padding(.vertical, 4)

            // Reale Ausschnittsmaße
            HStack(spacing: 8) {
                metricColumn(title: "FELD-BREITE", value: settings.formattedDistance(fieldWidthM), isAccent: true)
                Divider().background(AppSettings.border)
                metricColumn(title: "FELD-HÖHE", value: settings.formattedDistance(fieldHeightM), isAccent: true)
            }
            .padding(.vertical, 8)
            .background(AppSettings.cardBackgroundRaised.cornerRadius(12))

            // Bildwinkel Zeile
            HStack(spacing: 8) {
                metricColumn(title: "HORIZONTAL", value: String(format: "%.1f°", horizAOVdeg))
                Divider().background(AppSettings.border)
                metricColumn(title: "VERTIKAL", value: String(format: "%.1f°", vertAOVdeg))
                Divider().background(AppSettings.border)
                metricColumn(title: "DIAGONAL", value: String(format: "%.1f°", diagAOVdeg))
            }
            .padding(.vertical, 8)
            .background(AppSettings.cardBackgroundRaised.cornerRadius(12))

            Text("Exakt berechnet mit Dünne-Linsen-Nahfokus-Korrektur: sensor · (s - f) / f.")
                .font(.system(size: 11))
                .foregroundColor(AppSettings.tertiaryText)
        }
        .padding(18)
        .background(AppSettings.cardBackground)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppSettings.border, lineWidth: 1))
    }

    private func metricColumn(title: String, value: String, isAccent: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(AppSettings.tertiaryText)
                .tracking(0.6)

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(isAccent ? AppSettings.accentAmber : AppSettings.primaryText)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - B. Parameter-Karte
    private var parametersCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("PARAMETER")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppSettings.secondaryText)
                .tracking(0.8)

            // Brennweite
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Brennweite")
                        .foregroundColor(AppSettings.primaryText)
                    Spacer()
                    Text("\(Int(round(focalLength))) mm")
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppSettings.accentAmber)
                }

                if lens.isZoom && lens.maxFocalLengthMM > lens.minFocalLengthMM {
                    Slider(
                        value: Binding(
                            get: { focalLength },
                            set: { settings.focalLength = $0 }
                        ),
                        in: lens.minFocalLengthMM...lens.maxFocalLengthMM,
                        step: 1
                    )
                    .tint(AppSettings.accentAmber)
                } else {
                    Slider(
                        value: Binding(
                            get: { focalLength },
                            set: { settings.focalLength = $0 }
                        ),
                        in: max(10, focalLength - 5)...max(50, focalLength + 5),
                        step: 1
                    )
                    .tint(AppSettings.accentAmber)
                    .disabled(true)
                }
            }

            Divider().background(AppSettings.border)

            // Distanz
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Entfernung")
                        .foregroundColor(AppSettings.primaryText)
                    Spacer()

                    Button(action: {
                        let step = distanceM > 5 ? 1.0 : (distanceM > 1 ? 0.2 : 0.05)
                        settings.subjectDistance = equipment.clampDistance(distanceM - step)
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background(AppSettings.controlBackground.cornerRadius(8))
                            .foregroundColor(AppSettings.primaryText)
                    }

                    Text(settings.formattedDistance(distanceM))
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppSettings.accentAmber)
                        .frame(minWidth: 80, alignment: .center)

                    Button(action: {
                        let step = distanceM > 5 ? 1.0 : (distanceM > 1 ? 0.2 : 0.05)
                        settings.subjectDistance = distanceM + step
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background(AppSettings.controlBackground.cornerRadius(8))
                            .foregroundColor(AppSettings.primaryText)
                    }
                }

                Slider(
                    value: Binding(
                        get: { min(50.0, distanceM) },
                        set: { settings.subjectDistance = equipment.clampDistance($0) }
                    ),
                    in: lens.minimumFocusDistanceM...50.0,
                    step: 0.1
                )
                .tint(AppSettings.accentAmber)
            }
        }
        .padding(18)
        .background(AppSettings.cardBackground)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppSettings.border, lineWidth: 1))
    }
}

// MARK: - Visueller Rahmen mit 1,75 m Personensilhouette
public struct FieldFrameGraphicView: View {
    public let fieldWidthM: Double
    public let fieldHeightM: Double

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // 3:2 oder 4:3 Rahmen zeichnen
            let frameAspect = fieldWidthM > 0 && fieldHeightM > 0 ? CGFloat(fieldWidthM / fieldHeightM) : CGFloat(1.5)

            var rectW = w * 0.85
            var rectH = rectW / frameAspect
            if rectH > h * 0.85 {
                rectH = h * 0.85
                rectW = rectH * frameAspect
            }

            let rect = CGRect(x: (w - rectW) / 2.0, y: (h - rectH) / 2.0, width: rectW, height: rectH)

            // Höhe einer 1,75 m Person relativ zur Bildfeldhöhe
            let personHeightM = 1.75
            let personFrac = CGFloat(min(1.0, max(0.05, personHeightM / max(0.1, fieldHeightM))))
            let renderedPersonH = min(rectH * 0.95, rectH * personFrac)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppSettings.cardBackgroundRaised)

                // Kamerasucher / Bildfeld-Rahmen
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppSettings.accentAmber, lineWidth: 1.5)
                    .frame(width: rectW, height: rectH)

                // Ecken-Markierungen für Sucher-Look
                Path { p in
                    let arm: CGFloat = 10.0
                    // Oben links
                    p.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
                    p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                    p.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))

                    // Oben rechts
                    p.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))

                    // Unten links
                    p.move(to: CGPoint(x: rect.minX, y: rect.maxY - arm))
                    p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                    p.addLine(to: CGPoint(x: rect.minX + arm, y: rect.maxY))

                    // Unten rechts
                    p.move(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
                }
                .stroke(AppSettings.accentAmber, lineWidth: 2.5)

                // 1,75 m Person Silhouette
                VStack(spacing: 2) {
                    Image(systemName: "figure.stand")
                        .resizable()
                        .scaledToFit()
                        .frame(height: max(14, renderedPersonH - 12))
                        .foregroundColor(AppSettings.primaryText)

                    Text("1,75 m")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(AppSettings.secondaryText)
                }
                .position(x: rect.midX, y: rect.maxY - renderedPersonH / 2.0)
            }
        }
    }
}
