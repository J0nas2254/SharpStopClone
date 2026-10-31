//
//  NDView.swift
//  FieldSharp (Clean-Room-Nachbau)
//
//  Tab 4: ND-Filter Belichtungszeit-Rechner
//

import SwiftUI

public struct NDView: View {
    @EnvironmentObject var settings: AppSettings

    // Ungefilterte Verschlusszeit (Sekunden)
    @State private var baseTimeSeconds: Double = 1.0 / 250.0
    @State private var stops: Int = 10

    // Typische fotografische Belichtungszeiten
    private let standardShutterSpeeds: [(title: String, seconds: Double)] = [
        ("1/8000", 1.0 / 8000.0),
        ("1/4000", 1.0 / 4000.0),
        ("1/2000", 1.0 / 2000.0),
        ("1/1000", 1.0 / 1000.0),
        ("1/500", 1.0 / 500.0),
        ("1/250", 1.0 / 250.0),
        ("1/125", 1.0 / 125.0),
        ("1/60", 1.0 / 60.0),
        ("1/30", 1.0 / 30.0),
        ("1/15", 1.0 / 15.0),
        ("1/8", 1.0 / 8.0),
        ("1/4", 1.0 / 4.0),
        ("1/2", 0.5),
        ("1 s", 1.0),
        ("2 s", 2.0),
        ("4 s", 4.0),
        ("8 s", 8.0),
        ("15 s", 15.0),
        ("30 s", 30.0)
    ]

    private var calculatedTimeSeconds: Double {
        ndExposureTime(baseTimeSeconds: baseTimeSeconds, stops: stops)
    }

    private var density: Double {
        opticalDensity(stops: stops)
    }

    private var factor: Double {
        ndFactor(stops: stops)
    }

    private var baseTimeDisplay: String {
        formattedExposureTime(seconds: baseTimeSeconds)
    }

    private var dynamicSentence: String {
        let baseStr = baseTimeDisplay
        let resStr = formattedExposureTime(seconds: calculatedTimeSeconds)
        let densStr = String(format: "%.1f", density)
        let facStr = String(format: "%.0f×", factor)
        return "\(baseStr) ungefiltert wird mit \(stops) Stufen (ND \(densStr) · \(facStr)) zu \(resStr)."
    }

    private var isOver30Minutes: Bool {
        calculatedTimeSeconds > 1800.0
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Ergebnis-Karte oben
                resultCard

                // MARK: - Filter-Stärke (Stufen & Presets)
                filterStrengthCard

                // MARK: - Ungefilterte Verschlusszeit
                baseShutterCard
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
                    .fill(isOver30Minutes ? AppSettings.warningCoral : AppSettings.accentAmber)
                    .frame(width: 4, height: 48)

                Text(dynamicSentence)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppSettings.primaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Große Anzeige der berechneten Zeit
            VStack(spacing: 4) {
                Text("BERECHNETE BELICHTUNGSZEIT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppSettings.tertiaryText)
                    .tracking(0.8)

                Text(formattedExposureTime(seconds: calculatedTimeSeconds))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.accentAmber)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppSettings.cardBackgroundRaised.cornerRadius(14))

            // Warnhinweis bei > 30 Minuten
            if isOver30Minutes {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppSettings.warningCoral)
                    Text("Belichtungszeit über 30 min: Akku, Sensorerwärmung und Rauschen beachten.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppSettings.warningCoral)
                }
                .padding(10)
                .background(AppSettings.warningCoral.opacity(0.12))
                .cornerRadius(10)
            }

            // 3 Metriken: BLENDENSTUFEN | OPTISCHE DICHTE | FAKTOR
            HStack(spacing: 8) {
                metricColumn(title: "BLENDENSTUFEN", value: "+\(stops) EV")
                Divider().background(AppSettings.border)
                metricColumn(title: "OPTISCHE DICHTE", value: String(format: "ND %.1f", density))
                Divider().background(AppSettings.border)
                metricColumn(title: "FAKTOR", value: String(format: "%.0f×", factor))
            }
            .padding(.vertical, 8)
            .background(AppSettings.cardBackgroundRaised.cornerRadius(12))
        }
        .padding(18)
        .background(AppSettings.cardBackground)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppSettings.border, lineWidth: 1))
    }

    private func metricColumn(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(AppSettings.tertiaryText)
                .tracking(0.6)

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(AppSettings.primaryText)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - B. Filter-Stärke Karte
    private var filterStrengthCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ND-FILTER STÄRKE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppSettings.secondaryText)
                    .tracking(0.8)

                Spacer()

                Text("\(stops) Stufen")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.accentAmber)
            }

            // Schnellauswahl Standard-ND-Filter
            HStack(spacing: 8) {
                filterPresetButton(label: "3 Stufen (ND8)", value: 3)
                filterPresetButton(label: "6 Stufen (ND64)", value: 6)
                filterPresetButton(label: "10 Stufen (ND1000)", value: 10)
                filterPresetButton(label: "15 Stufen", value: 15)
            }

            // Stepper / Slider 0 bis 20 Stufen
            HStack {
                Button(action: { stops = max(0, stops - 1) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(AppSettings.controlBackground.cornerRadius(8))
                        .foregroundColor(AppSettings.primaryText)
                }

                Slider(
                    value: Binding(
                        get: { Double(stops) },
                        set: { stops = Int(round($0)) }
                    ),
                    in: 0...20,
                    step: 1
                )
                .tint(AppSettings.accentAmber)

                Button(action: { stops = min(20, stops + 1) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(AppSettings.controlBackground.cornerRadius(8))
                        .foregroundColor(AppSettings.primaryText)
                }
            }
        }
        .padding(18)
        .background(AppSettings.cardBackground)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppSettings.border, lineWidth: 1))
    }

    private func filterPresetButton(label: String, value: Int) -> some View {
        Button(action: { stops = value }) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(stops == value ? AppSettings.accentAmber : AppSettings.controlBackground)
                .foregroundColor(stops == value ? .black : AppSettings.primaryText)
                .cornerRadius(10)
        }
    }

    // MARK: - C. Ungefilterte Verschlusszeit Karte
    private var baseShutterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("UNGEFILTERTE ZEIT")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppSettings.secondaryText)
                    .tracking(0.8)

                Spacer()

                Text(baseTimeDisplay)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.accentAmber)
            }

            // Horizontale Leiste der Standard-Zeiten
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(standardShutterSpeeds, id: \.seconds) { item in
                        let isSelected = abs(baseTimeSeconds - item.seconds) < 1e-6
                        Button(action: {
                            baseTimeSeconds = item.seconds
                        }) {
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isSelected ? AppSettings.accentAmber : AppSettings.controlBackground)
                                .foregroundColor(isSelected ? .black : AppSettings.primaryText)
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(AppSettings.cardBackground)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppSettings.border, lineWidth: 1))
    }
}
