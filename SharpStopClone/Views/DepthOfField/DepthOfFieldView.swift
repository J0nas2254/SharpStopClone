//
//  DepthOfFieldView.swift
//  FieldSharp (Clean-Room-Nachbau)
//
//  Tab 1: Schärfentiefe & Hyperfokale Distanz
//

import SwiftUI
import QuickLook

public struct DepthOfFieldView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var equipment: EquipmentManager

    @State private var showingPDFCard = false
    @State private var pdfURL: URL? = nil

    private var camera: CameraBody {
        equipment.selectedCamera ?? equipment.cameras.first ?? CameraBody(name: "Standard", sensorFormat: .fullFrame)
    }

    private var lens: Lens {
        equipment.selectedLens ?? equipment.lenses.first ?? Lens(name: "Standard", isZoom: false, minFocalLengthMM: 50, maxFocalLengthMM: 50, maxApertureWide: 1.8, sensorFormat: .fullFrame)
    }

    private var focalLength: Double {
        equipment.clampFocalLength(settings.focalLength)
    }

    private var aperture: Double {
        equipment.clampAperture(settings.aperture, focalLength: focalLength)
    }

    private var distanceM: Double {
        equipment.clampDistance(settings.subjectDistance)
    }

    private var distanceMM: Double {
        distanceM * 1000.0
    }

    private var hyperfocalMM: Double {
        hyperfocalDistance(focalLength: focalLength, aperture: aperture, sensorFormat: camera.sensorFormat)
    }

    private var hyperfocalM: Double {
        hyperfocalMM / 1000.0
    }

    private var dofData: (near: Double, far: Double, farIsInfinity: Bool, frontDOF: Double, rearDOF: Double, totalDOF: Double) {
        depthOfFieldComponents(focalLength: focalLength, aperture: aperture, distance: distanceMM, sensorFormat: camera.sensorFormat)
    }

    private var nearM: Double { dofData.near / 1000.0 }
    private var farM: Double { dofData.far / 1000.0 }
    private var isFarInfinity: Bool { dofData.farIsInfinity }
    private var frontM: Double { dofData.frontDOF / 1000.0 }
    private var rearM: Double { dofData.rearDOF / 1000.0 }
    private var totalM: Double { dofData.totalDOF / 1000.0 }

    // MARK: - 3-Zustände der dynamischen Headline
    private var headlineData: (text: String, color: Color) {
        let diffToH = abs(distanceM - hyperfocalM)
        let relDiff = hyperfocalM > 0 ? (diffToH / hyperfocalM) : 1.0

        if isFarInfinity || relDiff < 0.05 {
            let halfHStr = settings.formattedDistance(hyperfocalM / 2.0)
            return ("Scharf bis zum Horizont (ab \(halfHStr))", AppSettings.successMint)
        } else if !isFarInfinity && totalM < 0.10 {
            let cm = max(0.1, round(totalM * 1000.0) / 10.0)
            let cmStr = cm == floor(cm) ? "\(Int(cm)) cm" : String(format: "%.1f cm", cm)
            return ("Extrem knappe Schärfe: nur \(cmStr)", AppSettings.warningCoral)
        } else {
            let frontPct: Int
            let rearPct: Int
            if isFarInfinity {
                frontPct = 0
                rearPct = 100
            } else {
                let sum = frontM + rearM
                if sum > 0 {
                    frontPct = Int(round((frontM / sum) * 100.0))
                    rearPct = 100 - frontPct
                } else {
                    frontPct = 50
                    rearPct = 50
                }
            }
            let totStr = settings.formattedDistance(totalM)
            return ("\(totStr) Schärfentiefe (\(frontPct) % davor, \(rearPct) % dahinter)", AppSettings.accentAmber)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - A. Ergebnis-Karte oben
                resultCard

                // MARK: - B. Ausrüstungs-Chips
                equipmentChipsCard

                // MARK: - C. Parameter-Steuerung
                parametersCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppSettings.appBackground.ignoresSafeArea())
        .sheet(isPresented: $showingPDFCard) {
            HyperfocalPDFSheet(
                camera: camera,
                lens: lens,
                focalLength: focalLength,
                useImperial: settings.useImperialUnits
            )
        }
    }

    // MARK: - A. Ergebnis-Karte
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Dynamische Headline mit farbigem Akzentbalken
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(headlineData.color)
                    .frame(width: 4, height: 48)

                Text(headlineData.text)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppSettings.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
            }

            // Visuelle Seitensicht-Grafik
            DepthSceneGraphicView(
                focusDistance: distanceM,
                nearLimit: nearM,
                farLimit: farM,
                isFarInfinity: isFarInfinity,
                hyperfocal: hyperfocalM
            )
            .frame(height: 125)
            .padding(.vertical, 4)

            // 3-Spalten: NAH | FOKUS | FERN
            HStack(spacing: 8) {
                metricColumn(title: "NAH", value: settings.formattedDistance(nearM))
                Divider().background(AppSettings.border)
                metricColumn(title: "FOKUS", value: settings.formattedDistance(distanceM), isAccent: true)
                Divider().background(AppSettings.border)
                metricColumn(title: "FERN", value: isFarInfinity ? "∞" : settings.formattedDistance(farM))
            }
            .padding(.vertical, 8)
            .background(AppSettings.cardBackgroundRaised.cornerRadius(12))

            // 3-Spalten: GESAMT | HYPERFOKAL | DAHINTER
            HStack(spacing: 8) {
                let totalStr = isFarInfinity ? "∞" : settings.formattedDistance(totalM)
                metricColumn(title: "SCHÄRFENTIEFE", value: totalStr)
                Divider().background(AppSettings.border)
                metricColumn(title: "HYPERFOKAL", value: settings.formattedDistance(hyperfocalM))
                Divider().background(AppSettings.border)
                let rearStr = isFarInfinity ? "∞" : settings.formattedDistance(rearM)
                metricColumn(title: "DAHINTER", value: rearStr)
            }
            .padding(.vertical, 8)
            .background(AppSettings.cardBackgroundRaised.cornerRadius(12))

            // Button "Auf Hyperfokal fokussieren"
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    settings.subjectDistance = hyperfocalM
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Auf Hyperfokal fokussieren (\(settings.formattedDistance(hyperfocalM)))")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(AppSettings.accentAmber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppSettings.accentAmber.opacity(0.12))
                .cornerRadius(10)
            }
        }
        .padding(18)
        .background(AppSettings.cardBackground)
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppSettings.border, lineWidth: 1)
        )
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

    // MARK: - B. Ausrüstungs-Chips
    private var equipmentChipsCard: some View {
        HStack(spacing: 12) {
            // Kamera-Chip
            Button(action: {
                settings.showingEquipmentSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(AppSettings.accentAmber)
                        .font(.system(size: 14))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(camera.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppSettings.primaryText)
                            .lineLimit(1)

                        Text(camera.sensorFormat.displayName)
                            .font(.system(size: 10))
                            .foregroundColor(AppSettings.secondaryText)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(AppSettings.tertiaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppSettings.cardBackgroundRaised)
                .cornerRadius(14)
            }

            // Objektiv-Chip
            Button(action: {
                settings.showingEquipmentSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.circle")
                        .foregroundColor(AppSettings.accentAmber)
                        .font(.system(size: 14))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lens.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppSettings.primaryText)
                            .lineLimit(1)

                        Text(lens.focalLengthDisplay)
                            .font(.system(size: 10))
                            .foregroundColor(AppSettings.secondaryText)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(AppSettings.tertiaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppSettings.cardBackgroundRaised)
                .cornerRadius(14)
            }
        }
    }

    // MARK: - C. Parameter-Steuerung
    private var parametersCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("PARAMETER")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppSettings.secondaryText)
                .tracking(0.8)

            // 1. Brennweite
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Brennweite")
                        .font(.system(size: 15, weight: .medium))
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

            // 2. Blende
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Blende")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppSettings.primaryText)

                    Spacer()

                    Text(settings.formattedAperture(aperture))
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppSettings.accentAmber)
                }

                // Standard-Blendenleiste
                let apertures: [Double] = [1.4, 1.8, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0]
                let minAp = lens.maxAperture(at: focalLength)
                let validApertures = apertures.filter { $0 >= minAp - 0.05 }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(validApertures, id: \.self) { ap in
                            let isSelected = abs(aperture - ap) < 0.1
                            Button(action: {
                                settings.aperture = ap
                            }) {
                                Text(settings.formattedAperture(ap))
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

            Divider().background(AppSettings.border)

            // 3. Entfernung (Fokusdistanz)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Entfernung")
                        .font(.system(size: 15, weight: .medium))
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
                        get: { min(100.0, distanceM) },
                        set: { settings.subjectDistance = equipment.clampDistance($0) }
                    ),
                    in: lens.minimumFocusDistanceM...100.0,
                    step: 0.1
                )
                .tint(AppSettings.accentAmber)
            }

            Divider().background(AppSettings.border)

            // Aktionen
            HStack(spacing: 12) {
                Button(action: {
                    showingPDFCard = true
                }) {
                    Label("Hyperfokal-Karte (PDF)", systemImage: "printer")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppSettings.controlBackground)
                        .foregroundColor(AppSettings.primaryText)
                        .cornerRadius(14)
                }

                Button(action: {
                    settings.showingGlossarySheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.pages")
                        Text("Glossar")
                    }
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppSettings.controlBackground)
                    .foregroundColor(AppSettings.accentAmber)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppSettings.accentAmber.opacity(0.4), lineWidth: 1))
                }
            }
        }
        .padding(18)
        .background(AppSettings.cardBackground)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppSettings.border, lineWidth: 1))
    }
}

// MARK: - Seitliche Szenengrafik
public struct DepthSceneGraphicView: View {
    public let focusDistance: Double
    public let nearLimit: Double
    public let farLimit: Double
    public let isFarInfinity: Bool
    public let hyperfocal: Double

    private var maxM: Double {
        max(hyperfocal * 1.3, max(focusDistance * 2.2, 15.0))
    }

    private func xPos(for m: Double, width: CGFloat) -> CGFloat {
        guard m > 0 else { return 36.0 }
        let norm = log10(1.0 + (m / maxM) * 9.0)
        return 40.0 + CGFloat(norm) * (width - 70.0)
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let camX: CGFloat = 16.0
            let focusX = xPos(for: focusDistance, width: w)
            let nearX = max(camX + 10, xPos(for: nearLimit, width: w))
            let farX = isFarInfinity ? (w - 10) : min(w - 10, xPos(for: farLimit, width: w))
            let bandWidth = max(4.0, farX - nearX)

            ZStack(alignment: .topLeading) {
                // Hintergrund Horizont & Landschaft
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppSettings.cardBackgroundRaised)

                // Berge & Bäume im Hintergrund
                Path { p in
                    p.move(to: CGPoint(x: w * 0.65, y: h * 0.55))
                    p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.25))
                    p.addLine(to: CGPoint(x: w * 0.95, y: h * 0.55))
                    p.closeSubpath()
                }
                .fill(Color(white: 0.15))

                // Baum
                Image(systemName: "tree.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(white: 0.22))
                    .position(x: min(w - 30, focusX + 45), y: h * 0.45)

                // Schärfeband
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppSettings.accentAmber.opacity(0.35))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppSettings.accentAmber, lineWidth: 1.5))
                    .frame(width: bandWidth, height: h * 0.38)
                    .position(x: nearX + bandWidth / 2.0, y: h * 0.5)

                if isFarInfinity {
                    Text("scharf bis ∞")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppSettings.accentAmber)
                        .position(x: w - 42, y: h * 0.22)
                }

                // Kamera links
                VStack(spacing: 2) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 15))
                        .foregroundColor(AppSettings.primaryText)
                    Text("0 m")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(AppSettings.tertiaryText)
                }
                .position(x: camX + 8, y: h * 0.5)

                // Motiv (Person)
                VStack(spacing: 2) {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 22))
                        .foregroundColor(AppSettings.primaryText)
                    Text("Motiv")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(AppSettings.accentAmber)
                }
                .position(x: focusX, y: h * 0.45)

                // Gestrichelte Fokuslinie
                Path { p in
                    p.move(to: CGPoint(x: focusX, y: 10))
                    p.addLine(to: CGPoint(x: focusX, y: h - 18))
                }
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundColor(AppSettings.accentAmber)

                // Bodenlinie & Distanzachse
                Path { p in
                    p.move(to: CGPoint(x: 10, y: h - 16))
                    p.addLine(to: CGPoint(x: w - 10, y: h - 16))
                }
                .stroke(AppSettings.border, lineWidth: 1)

                // Achsenmarken
                Text("Nah")
                    .font(.system(size: 8))
                    .foregroundColor(AppSettings.secondaryText)
                    .position(x: nearX, y: h - 8)

                if !isFarInfinity {
                    Text("Fern")
                        .font(.system(size: 8))
                        .foregroundColor(AppSettings.secondaryText)
                        .position(x: farX, y: h - 8)
                }

                Text("∞")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppSettings.tertiaryText)
                    .position(x: w - 16, y: h - 8)
            }
        }
    }
}

// MARK: - PDF Vorschau Sheet
public struct HyperfocalPDFSheet: View {
    @Environment(\.dismiss) var dismiss
    public let camera: CameraBody
    public let lens: Lens
    public let focalLength: Double
    public let useImperial: Bool

    @State private var pdfData: Data? = nil
    @State private var pdfTempURL: URL? = nil

    public var body: some View {
        NavigationStack {
            VStack {
                if let url = pdfTempURL {
                    PDFKitRepresentedView(url: url)
                } else {
                    ProgressView("Erstelle PDF …")
                        .foregroundColor(AppSettings.accentAmber)
                }
            }
            .background(AppSettings.appBackground.ignoresSafeArea())
            .navigationTitle("Hyperfokal-Karte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundColor(AppSettings.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let url = pdfTempURL {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(AppSettings.accentAmber)
                        }
                    }
                }
            }
            .onAppear {
                generatePDF()
            }
        }
    }

    private func generatePDF() {
        let data = HyperfocalPDFGenerator.generatePDF(
            camera: camera,
            lens: lens,
            focalLengthMM: focalLength,
            useImperial: useImperial
        )
        self.pdfData = data

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("Hyperfokal-Karte-\(Int(round(focalLength)))mm.pdf")
        try? data.write(to: fileURL)
        self.pdfTempURL = fileURL
    }
}

// MARK: - PDFKit Wrapper
#if canImport(PDFKit)
import PDFKit

public struct PDFKitRepresentedView: UIViewRepresentable {
    public let url: URL

    public func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.backgroundColor = UIColor(AppSettings.appBackground)
        return pdfView
    }

    public func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}
#endif
