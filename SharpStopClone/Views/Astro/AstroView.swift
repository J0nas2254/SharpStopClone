//
//  AstroView.swift
//  FieldSharp (Clean-Room-Nachbau)
//
//  Tab 3: Milchstraßenkern & Sternspuren (NPF- / 500er-Regel)
//

import SwiftUI

public struct AstroView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var equipment: EquipmentManager

    @State private var megapixels: Double = 33.0
    @State private var showingAddPlaceSheet = false
    @State private var logConfirmationToast: Bool = false

    private var camera: CameraBody {
        equipment.selectedCamera ?? equipment.cameras.first ?? CameraBody(name: "Vollformat", sensorFormat: .fullFrame, megapixels: megapixels)
    }

    private var lens: Lens {
        equipment.selectedLens ?? equipment.lenses.first ?? Lens(name: "14mm f/1.8", isZoom: false, minFocalLengthMM: 14, maxFocalLengthMM: 14, maxApertureWide: 1.8, sensorFormat: .fullFrame)
    }

    private var focalLength: Double {
        equipment.clampFocalLength(settings.focalLength)
    }

    private var aperture: Double {
        equipment.clampAperture(settings.aperture, focalLength: focalLength)
    }

    // NPF & 500er-Berechnungen
    private var pWidth: Int {
        pixelWidth(sensorMP: megapixels, sensorWidthMM: camera.sensorFormat.sensorWidthMM, sensorHeightMM: camera.sensorFormat.sensorHeightMM)
    }

    private var pPitch: Double {
        pixelPitch(sensorWidthMM: camera.sensorFormat.sensorWidthMM, pixelWidth: pWidth)
    }

    private var npfTime: Double {
        npfShutterTime(focalLength: focalLength, aperture: aperture, pixelPitchMicrons: pPitch)
    }

    private var rule500Time: Double {
        npf500Rule(focalLength: focalLength, sensorFormat: camera.sensorFormat)
    }

    // Milchstraßen-Analyse
    private var nightPlan: MilkyWayNightPlan {
        analyzeMilkyWayNight(
            nightDate: settings.selectedAstroDate,
            latitude: settings.selectedPlace.latitude,
            longitude: settings.selectedPlace.longitude,
            timeZone: settings.selectedPlace.timeZone
        )
    }

    private var dynamicAstroSentence: String {
        if nightPlan.isVisible, let s = nightPlan.windowStart, let e = nightPlan.windowEnd {
            let df = DateFormatter()
            df.timeZone = settings.selectedPlace.timeZone
            df.dateFormat = "HH:mm"
            let startStr = df.string(from: s)
            let endStr = df.string(from: e)
            return "Gute Nacht für das Zentrum: sichtbar \(startStr)–\(endStr), Mond \(Int(round(nightPlan.moonIllumination))) %, Richtung \(nightPlan.peakDirection)"
        } else {
            return "Kein vollständig dunkles Fenster für das Zentrum."
        }
    }

    private var dynamicStarTrailsSentence: String {
        let npfStr = String(format: "%.1f s", npfTime)
        let r500Str = String(format: "%.1f s", rule500Time)
        return "\(npfStr), bevor Sterne Striche ziehen; die \(r500Str) der 500er-Regel sind bei \(Int(round(megapixels))) MP sichtbar länger."
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - 1. Milchstraßenkern-Bereich
                galacticCenterSection

                // MARK: - 2. Sternspuren / NPF-Bereich
                starTrailsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppSettings.appBackground.ignoresSafeArea())
        .sheet(isPresented: $settings.showingBestNightsSheet) {
            BestNightsSheetView()
        }
        .sheet(isPresented: $settings.showingNightLogsSheet) {
            NightLogSheetView()
        }
        .sheet(isPresented: $showingAddPlaceSheet) {
            AddPlaceSheetView()
        }
        .overlay(alignment: .bottom) {
            if logConfirmationToast {
                Text("Nacht im Logbuch gespeichert")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppSettings.successMint)
                    .foregroundColor(.black)
                    .cornerRadius(20)
                    .shadow(radius: 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - 1. Milchstraßenkern
    private var galacticCenterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("ZENTRUM DER MILCHSTRASSE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppSettings.secondaryText)
                    .tracking(0.8)

                Spacer()

                Button("Nacht-Logbuch") {
                    settings.showingNightLogsSheet = true
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppSettings.accentAmber)
            }

            // Status Headline
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(nightPlan.isVisible ? AppSettings.successMint : AppSettings.warningCoral)
                    .frame(width: 4, height: 48)

                Text(dynamicAstroSentence)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppSettings.primaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Datum & Ort-Auswahl
            HStack(spacing: 8) {
                // Pfeil zurück
                Button(action: {
                    settings.selectedAstroDate = Calendar.current.date(byAdding: .day, value: -1, to: settings.selectedAstroDate) ?? settings.selectedAstroDate
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .padding(8)
                        .background(AppSettings.controlBackground.cornerRadius(8))
                        .foregroundColor(AppSettings.primaryText)
                }

                // Datums-Anzeige
                let df: DateFormatter = {
                    let f = DateFormatter()
                    f.timeZone = settings.selectedPlace.timeZone
                    f.dateStyle = .medium
                    return f
                }()
                Text(df.string(from: settings.selectedAstroDate))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppSettings.primaryText)
                    .frame(maxWidth: .infinity)

                // Pfeil vor
                Button(action: {
                    settings.selectedAstroDate = Calendar.current.date(byAdding: .day, value: 1, to: settings.selectedAstroDate) ?? settings.selectedAstroDate
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .padding(8)
                        .background(AppSettings.controlBackground.cornerRadius(8))
                        .foregroundColor(AppSettings.primaryText)
                }

                // Heute Button
                Button("Heute") {
                    settings.selectedAstroDate = Date()
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppSettings.controlBackground.cornerRadius(8))
                .foregroundColor(AppSettings.accentAmber)
            }

            // Orts-Picker
            Menu {
                ForEach(settings.places) { place in
                    Button(place.name) {
                        settings.selectedPlace = place
                    }
                }
                Divider()
                Button(action: { showingAddPlaceSheet = true }) {
                    Label("Eigener Ort hinzufügen …", systemImage: "plus")
                }
            } label: {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                    Text(settings.selectedPlace.name)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11))
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(AppSettings.controlBackground.cornerRadius(10))
                .foregroundColor(AppSettings.primaryText)
            }

            // Diagramm über die Nacht (18:00 - 06:00)
            NightAltitudeChartView(
                nightDate: settings.selectedAstroDate,
                place: settings.selectedPlace,
                plan: nightPlan
            )
            .frame(height: 140)

            // Kennzahlen
            HStack(spacing: 8) {
                let windowStr: String = {
                    guard let s = nightPlan.windowStart, let e = nightPlan.windowEnd else { return "Nein" }
                    let tf = DateFormatter()
                    tf.timeZone = settings.selectedPlace.timeZone
                    tf.dateFormat = "HH:mm"
                    return "\(tf.string(from: s))–\(tf.string(from: e))"
                }()

                metricBox(title: "ZENTRUM SICHTBAR", value: windowStr, isAccent: nightPlan.isVisible)
                Divider().background(AppSettings.border)
                metricBox(title: "MOND", value: "\(Int(round(nightPlan.moonIllumination))) %")
                Divider().background(AppSettings.border)
                metricBox(title: "RICHTUNG", value: nightPlan.peakDirection)
            }
            .padding(.vertical, 8)
            .background(AppSettings.cardBackgroundRaised.cornerRadius(12))

            // Aktionen
            HStack(spacing: 12) {
                Button(action: {
                    settings.showingBestNightsSheet = true
                }) {
                    Label("Beste 3 Nächte", systemImage: "calendar.badge.clock")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(AppSettings.controlBackground.cornerRadius(12))
                        .foregroundColor(AppSettings.primaryText)
                }

                Button(action: {
                    logCurrentNight()
                }) {
                    Label("Nacht protokollieren", systemImage: "square.and.pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(AppSettings.controlBackground.cornerRadius(12))
                        .foregroundColor(AppSettings.accentAmber)
                }
            }
        }
        .padding(18)
        .background(AppSettings.cardBackground)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppSettings.border, lineWidth: 1))
    }

    private func logCurrentNight() {
        let entry = NightLogEntry(
            localNightDate: settings.selectedAstroDate,
            placeName: settings.selectedPlace.name,
            latitude: settings.selectedPlace.latitude,
            longitude: settings.selectedPlace.longitude,
            timeZoneIdentifier: settings.selectedPlace.timeZoneIdentifier,
            coreWindowStart: nightPlan.windowStart,
            coreWindowEnd: nightPlan.windowEnd,
            moonIllumination: nightPlan.moonIllumination,
            direction: nightPlan.peakDirection
        )
        settings.addNightLog(entry)
        withAnimation {
            logConfirmationToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                logConfirmationToast = false
            }
        }
    }

    // MARK: - 2. Sternspuren / NPF-Bereich
    private var starTrailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("STERNSPUREN & BELICHTUNGSZEIT")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppSettings.secondaryText)
                .tracking(0.8)

            // Dynamischer Satz
            Text(dynamicStarTrailsSentence)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppSettings.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            // NPF vs 500er Kennzahlen
            HStack(spacing: 8) {
                metricBox(title: "NPF-REGEL", value: String(format: "%.1f s", npfTime), isAccent: true)
                Divider().background(AppSettings.border)
                metricBox(title: "500ER-REGEL", value: String(format: "%.1f s", rule500Time))
                Divider().background(AppSettings.border)
                metricBox(title: "PIXELABSTAND", value: String(format: "%.2f µm", pPitch))
            }
            .padding(.vertical, 8)
            .background(AppSettings.cardBackgroundRaised.cornerRadius(12))

            // Steuerung Megapixel
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sensor-Auflösung")
                        .font(.system(size: 14))
                        .foregroundColor(AppSettings.primaryText)
                    Spacer()

                    Button(action: { megapixels = max(8.0, megapixels - 1.0) }) {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background(AppSettings.controlBackground.cornerRadius(8))
                            .foregroundColor(AppSettings.primaryText)
                    }

                    Text("\(Int(round(megapixels))) MP")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.accentAmber)
                        .frame(minWidth: 70, alignment: .center)

                    Button(action: { megapixels = min(150.0, megapixels + 1.0) }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background(AppSettings.controlBackground.cornerRadius(8))
                            .foregroundColor(AppSettings.primaryText)
                    }
                }

                Text("Pixelbreite: \(pWidth) px · Auf hochauflösenden Sensoren führt die 500er-Regel zu sichtbaren Strichen; nutze die NPF-Zeit.")
                    .font(.system(size: 11))
                    .foregroundColor(AppSettings.tertiaryText)
            }
        }
        .padding(18)
        .background(AppSettings.cardBackground)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppSettings.border, lineWidth: 1))
    }

    private func metricBox(title: String, value: String, isAccent: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(AppSettings.tertiaryText)
                .tracking(0.6)

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(isAccent ? AppSettings.accentAmber : AppSettings.primaryText)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Nacht-Höhendiagramm View
public struct NightAltitudeChartView: View {
    public let nightDate: Date
    public let place: Place
    public let plan: MilkyWayNightPlan

    private var dusk: Date {
        var cal = Calendar.current
        cal.timeZone = place.timeZone
        let startOfDay = cal.startOfDay(for: nightDate)
        return cal.date(bySettingHour: 18, minute: 0, second: 0, of: startOfDay) ?? nightDate
    }

    private let totalSeconds: Double = 12.0 * 3600.0 // 18:00 bis 06:00

    private func xForDate(_ d: Date, width: CGFloat) -> CGFloat {
        let diff = d.timeIntervalSince(dusk)
        let frac = max(0.0, min(1.0, diff / totalSeconds))
        return CGFloat(frac) * width
    }

    private func yForAlt(_ alt: Double, height: CGFloat) -> CGFloat {
        let minAlt = -20.0
        let maxAlt = 60.0
        let norm = (alt - minAlt) / (maxAlt - minAlt)
        return height - CGFloat(max(0.0, min(1.0, norm))) * height
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let y10 = yForAlt(10.0, height: h)
            let baseDusk = dusk

            ZStack(alignment: .topLeading) {
                // Hintergrund
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppSettings.cardBackgroundRaised)

                // Astronomische Dunkelheit Schattierung
                Rectangle()
                    .fill(Color.black.opacity(0.4))

                // 10° Referenzlinie
                Path { p in
                    p.move(to: CGPoint(x: 0, y: y10))
                    p.addLine(to: CGPoint(x: w, y: y10))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundColor(AppSettings.border)

                Text("10°")
                    .font(.system(size: 8))
                    .foregroundColor(AppSettings.tertiaryText)
                    .position(x: 16, y: y10 - 6)

                // Sichtbares Kernfenster amberfarben gefüllt
                if let s = plan.windowStart, let e = plan.windowEnd {
                    let xStart = xForDate(s, width: w)
                    let xEnd = xForDate(e, width: w)
                    let width = max(4.0, xEnd - xStart)

                    Rectangle()
                        .fill(AppSettings.accentAmber.opacity(0.18))
                        .frame(width: width, height: h)
                        .position(x: xStart + width / 2.0, y: h / 2.0)
                }

                // Höhenkurve des galaktischen Zentrums (Amber)
                Path { p in
                    var first = true
                    for m in stride(from: 0.0, through: totalSeconds, by: 600.0) {
                        let sampleDate = baseDusk.addingTimeInterval(m)
                        let core = galacticCenterPosition(date: sampleDate, latitude: place.latitude, longitude: place.longitude)
                        let pt = CGPoint(x: xForDate(sampleDate, width: w), y: yForAlt(core.altitude, height: h))
                        if first {
                            p.move(to: pt)
                            first = false
                        } else {
                            p.addLine(to: pt)
                        }
                    }
                }
                .stroke(AppSettings.accentAmber, lineWidth: 2)

                // Mondhöhenkurve (Grau gestrichelt)
                Path { p in
                    var first = true
                    for m in stride(from: 0.0, through: totalSeconds, by: 600.0) {
                        let sampleDate = baseDusk.addingTimeInterval(m)
                        let moon = moonDetails(date: sampleDate, latitude: place.latitude, longitude: place.longitude)
                        let pt = CGPoint(x: xForDate(sampleDate, width: w), y: yForAlt(moon.altitude, height: h))
                        if first {
                            p.move(to: pt)
                            first = false
                        } else {
                            p.addLine(to: pt)
                        }
                    }
                }
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .foregroundColor(AppSettings.secondaryText)

                // Beschriftung Spitzenhöhe
                if plan.maxCoreAltitude > 0 {
                    let peakY = yForAlt(plan.maxCoreAltitude, height: h)
                    Text("\(Int(round(plan.maxCoreAltitude)))°")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppSettings.accentAmber)
                        .position(x: w / 2.0, y: max(12, peakY - 8))
                }

                // X-Achsen Zeitleiste
                HStack {
                    Text("18:00")
                    Spacer()
                    Text("21:00")
                    Spacer()
                    Text("00:00")
                    Spacer()
                    Text("03:00")
                    Spacer()
                    Text("06:00")
                }
                .font(.system(size: 8))
                .foregroundColor(AppSettings.tertiaryText)
                .padding(.horizontal, 10)
                .position(x: w / 2.0, y: h - 10)
            }
        }
    }
}

// MARK: - Beste 3 Nächte Sheet
public struct BestNightsSheetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings

    private var topNights: [MilkyWayNightPlan] {
        bestNightsNext30Days(
            startDate: Date(),
            latitude: settings.selectedPlace.latitude,
            longitude: settings.selectedPlace.longitude,
            timeZone: settings.selectedPlace.timeZone
        )
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Beste Nächte für den Milchstraßenkern in den nächsten 30 Tagen, bewertet nach Zeitfensterdauer, Kernhöhe und minimaler Mondstörung.")
                        .font(.system(size: 13))
                        .foregroundColor(AppSettings.secondaryText)
                        .padding(.horizontal, 4)

                    if topNights.isEmpty {
                        Text("In den kommenden 30 Tagen gibt es an diesem Ort kein sichtbares astronomisch dunkles Fenster mit Kernhöhe ≥ 10°.")
                            .foregroundColor(AppSettings.secondaryText)
                            .padding(.top, 20)
                    } else {
                        ForEach(0..<topNights.count, id: \.self) { idx in
                            let night = topNights[idx]
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("#\(idx + 1)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppSettings.accentAmber)

                                    let df: DateFormatter = {
                                        let f = DateFormatter()
                                        f.timeZone = settings.selectedPlace.timeZone
                                        f.dateStyle = .full
                                        return f
                                    }()
                                    Text(df.string(from: night.date))
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(AppSettings.primaryText)

                                    Spacer()
                                }

                                HStack(spacing: 16) {
                                    if let s = night.windowStart, let e = night.windowEnd {
                                        let tf: DateFormatter = {
                                            let f = DateFormatter()
                                            f.timeZone = settings.selectedPlace.timeZone
                                            f.dateFormat = "HH:mm"
                                            return f
                                        }()
                                        VStack(alignment: .leading) {
                                            Text("FENSTER")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(AppSettings.tertiaryText)
                                            Text("\(tf.string(from: s))–\(tf.string(from: e))")
                                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                                .foregroundColor(AppSettings.accentAmber)
                                        }
                                    }

                                    VStack(alignment: .leading) {
                                        Text("MOND")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(AppSettings.tertiaryText)
                                        Text("\(Int(round(night.moonIllumination))) %")
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundColor(AppSettings.primaryText)
                                    }

                                    VStack(alignment: .leading) {
                                        Text("MAX HÖHE")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(AppSettings.tertiaryText)
                                        Text("\(Int(round(night.maxCoreAltitude)))°")
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundColor(AppSettings.primaryText)
                                    }

                                    VStack(alignment: .leading) {
                                        Text("RICHTUNG")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(AppSettings.tertiaryText)
                                        Text(night.peakDirection)
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundColor(AppSettings.primaryText)
                                    }
                                }
                            }
                            .padding(16)
                            .background(AppSettings.cardBackground)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppSettings.border, lineWidth: 1))
                        }
                    }
                }
                .padding(20)
            }
            .background(AppSettings.appBackground.ignoresSafeArea())
            .navigationTitle("Beste 3 Nächte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .foregroundColor(AppSettings.accentAmber)
                }
            }
        }
    }
}

// MARK: - Nacht-Logbuch Sheet
public struct NightLogSheetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings

    public var body: some View {
        NavigationStack {
            List {
                if settings.nightLogs.isEmpty {
                    Text("Noch keine Nächte protokolliert. Nutze 'Nacht protokollieren' im Sterne-Tab.")
                        .foregroundColor(AppSettings.secondaryText)
                        .listRowBackground(AppSettings.cardBackground)
                } else {
                    ForEach(settings.nightLogs) { log in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(log.placeName)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(AppSettings.primaryText)
                                Spacer()
                                let df: DateFormatter = {
                                    let f = DateFormatter()
                                    f.dateStyle = .medium
                                    return f
                                }()
                                Text(df.string(from: log.localNightDate))
                                    .font(.system(size: 12))
                                    .foregroundColor(AppSettings.tertiaryText)
                            }

                            HStack(spacing: 12) {
                                if let s = log.coreWindowStart, let e = log.coreWindowEnd {
                                    let tf: DateFormatter = {
                                        let f = DateFormatter()
                                        f.dateFormat = "HH:mm"
                                        return f
                                    }()
                                    Text("Fenster: \(tf.string(from: s))–\(tf.string(from: e))")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppSettings.accentAmber)
                                }
                                Text("Mond: \(Int(round(log.moonIllumination))) %")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppSettings.secondaryText)
                                Text("Richtung: \(log.direction)")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppSettings.secondaryText)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(AppSettings.cardBackground)
                    }
                    .onDelete(perform: settings.deleteNightLog)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppSettings.appBackground.ignoresSafeArea())
            .navigationTitle("Nacht-Logbuch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .foregroundColor(AppSettings.accentAmber)
                }
            }
        }
    }
}

// MARK: - Eigener Ort hinzufügen Sheet
public struct AddPlaceSheetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings

    @State private var name: String = ""
    @State private var latitudeStr: String = ""
    @State private var longitudeStr: String = ""
    @State private var timeZoneId: String = TimeZone.current.identifier

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Ort Details")) {
                    TextField("Name des Ortes", text: $name)
                    TextField("Breitengrad (z.B. 50.45)", text: $latitudeStr)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Längengrad (z.B. 10.02)", text: $longitudeStr)
                        .keyboardType(.numbersAndPunctuation)
                }

                Section(header: Text("Zeitzone"), footer: Text("Die Zeitzone gehört zum Ort, nicht zum aktuellen iPhone-Standort.")) {
                    Picker("Zeitzone", selection: $timeZoneId) {
                        ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { id in
                            Text(id).tag(id)
                        }
                    }
                }
            }
            .navigationTitle("Neuer Ort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let lat = Double(latitudeStr.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                        let lon = Double(longitudeStr.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                        let place = Place(
                            name: name.isEmpty ? "Mein Beobachtungsort" : name,
                            latitude: lat,
                            longitude: lon,
                            timeZoneIdentifier: timeZoneId,
                            isBuiltIn: false
                        )
                        settings.addCustomPlace(place)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
