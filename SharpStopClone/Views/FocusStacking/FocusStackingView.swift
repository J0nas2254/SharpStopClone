//
//  FocusStackingView.swift
//  FieldSharp (Clean-Room-Nachbau)
//
//  Tab 2: Fokus-Stacking Planer & Vor-Ort-Checkliste
//

import SwiftUI

public struct FocusStackingView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var equipment: EquipmentManager

    @State private var requestedNearM: Double = 0.40
    @State private var requestedFarM: Double = 10.0
    @State private var targetIsInfinity: Bool = true
    @State private var showingChecklist: Bool = false
    @State private var showingShareSheet: Bool = false

    private var camera: CameraBody {
        equipment.selectedCamera ?? equipment.cameras.first ?? CameraBody(name: "Standard", sensorFormat: .fullFrame)
    }

    private var lens: Lens {
        equipment.selectedLens ?? equipment.lenses.first ?? Lens(name: "Standard", isZoom: false, minFocalLengthMM: 24, maxFocalLengthMM: 24, maxApertureWide: 2.8, sensorFormat: .fullFrame)
    }

    private var clampedFocalLength: Double {
        equipment.clampFocalLength(settings.focalLength)
    }

    private var clampedAperture: Double {
        equipment.clampAperture(settings.aperture, focalLength: clampedFocalLength)
    }

    private var currentShots: [StackShot] {
        calculateFocusStack(
            focalLength: clampedFocalLength,
            aperture: clampedAperture,
            sensorFormat: camera.sensorFormat,
            requestedNearM: max(lens.minimumFocusDistanceM, requestedNearM),
            requestedFarM: targetIsInfinity ? nil : requestedFarM,
            overlapFraction: 0.15
        )
    }

    private var dynamicSentence: String {
        let count = currentShots.count
        if count == 0 {
            return "Keine Aufnahmen erforderlich oder ungültige Werte."
        }
        let points = currentShots.prefix(5).map { settings.formattedDistance($0.focusDistanceM) }.joined(separator: " · ")
        let more = count > 5 ? " …" : ""
        return "\(count) Aufnahmen: fokussiere auf \(points)\(more)"
    }

    private var shareText: String {
        var text = "Fokus-Stack\n"
        text += "\(camera.sensorFormat.shortName) · \(Int(round(clampedFocalLength))) mm · \(settings.formattedAperture(clampedAperture))\n"
        let farStr = targetIsInfinity ? "∞" : settings.formattedDistance(requestedFarM)
        text += "Scharf von \(settings.formattedDistance(requestedNearM)) bis \(farStr)\n\n"
        for shot in currentShots {
            text += "\(shot.index). Fokus \(settings.formattedDistance(shot.focusDistanceM))\n"
        }
        text += "\nÜberlappung: 15 % · Erstellt mit FieldSharp"
        return text
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Ergebnis-Karte oben
                resultCard

                // MARK: - Eingabeparameter
                inputCard

                // MARK: - Liste der Fokus-Positionen
                shotsListCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppSettings.appBackground.ignoresSafeArea())
        .sheet(isPresented: $showingChecklist) {
            StackChecklistSheet()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheetView(text: shareText)
        }
    }

    // MARK: - A. Ergebnis-Karte
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppSettings.accentAmber)
                    .frame(width: 4, height: 48)

                Text(dynamicSentence)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(AppSettings.primaryText)
                    .lineLimit(3)
                    .contentTransition(.numericText())
            }

            // Visuelle Grafik mit überlappenden Schärfebändern
            StackSceneGraphicView(shots: currentShots)
                .frame(height: 110)
                .padding(.vertical, 4)

            // Aktionsbuttons
            HStack(spacing: 12) {
                Button(action: {
                    let plan = FocusStackPlan(
                        cameraName: camera.name,
                        sensorFormat: camera.sensorFormat,
                        focalLengthMM: clampedFocalLength,
                        aperture: clampedAperture,
                        requestedNearM: requestedNearM,
                        requestedFarM: targetIsInfinity ? nil : requestedFarM,
                        overlapFraction: 0.15,
                        shots: currentShots
                    )
                    settings.activeStackPlan = plan
                    showingChecklist = true
                }) {
                    Label("Checkliste starten", systemImage: "checklist")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppSettings.accentAmber)
                        .foregroundColor(.black)
                        .cornerRadius(14)
                }

                Button(action: { showingShareSheet = true }) {
                    Label("Plan teilen", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(AppSettings.controlBackground)
                        .foregroundColor(AppSettings.primaryText)
                        .cornerRadius(14)
                }
            }
        }
        .padding(18)
        .background(AppSettings.cardBackground)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppSettings.border, lineWidth: 1))
    }

    // MARK: - B. Eingabeparameter
    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MOTIVBEREICH")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppSettings.secondaryText)
                .tracking(0.8)

            // Gewünschter Nahpunkt
            HStack {
                Text("Gewünschte Nahgrenze")
                    .foregroundColor(AppSettings.primaryText)
                Spacer()

                Button(action: {
                    requestedNearM = max(lens.minimumFocusDistanceM, requestedNearM - 0.05)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(AppSettings.controlBackground.cornerRadius(8))
                        .foregroundColor(AppSettings.primaryText)
                }

                Text(settings.formattedDistance(requestedNearM))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppSettings.accentAmber)
                    .frame(minWidth: 70, alignment: .center)

                Button(action: {
                    requestedNearM += 0.05
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(AppSettings.controlBackground.cornerRadius(8))
                        .foregroundColor(AppSettings.primaryText)
                }
            }

            Divider().background(AppSettings.border)

            // Gewünschte Ferngrenze oder Unendlich
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Gewünschte Ferngrenze")
                        .foregroundColor(AppSettings.primaryText)
                    Spacer()
                    Toggle("Bis ∞", isOn: $targetIsInfinity)
                        .labelsHidden()
                        .tint(AppSettings.accentAmber)
                    Text("∞")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(targetIsInfinity ? AppSettings.accentAmber : AppSettings.tertiaryText)
                }

                if !targetIsInfinity {
                    HStack {
                        Spacer()
                        Button(action: {
                            requestedFarM = max(requestedNearM + 0.2, requestedFarM - 0.5)
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(AppSettings.controlBackground.cornerRadius(8))
                                .foregroundColor(AppSettings.primaryText)
                        }

                        Text(settings.formattedDistance(requestedFarM))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppSettings.accentAmber)
                            .frame(minWidth: 70, alignment: .center)

                        Button(action: {
                            requestedFarM += 0.5
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(AppSettings.controlBackground.cornerRadius(8))
                                .foregroundColor(AppSettings.primaryText)
                        }
                    }
                }
            }

            Divider().background(AppSettings.border)

            HStack {
                Text("Überlappung")
                    .foregroundColor(AppSettings.secondaryText)
                    .font(.system(size: 13))
                Spacer()
                Text("15 % (optimiert)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppSettings.primaryText)
            }
        }
        .padding(18)
        .background(AppSettings.cardBackground)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppSettings.border, lineWidth: 1))
    }

    // MARK: - C. Liste der Fokus-Positionen
    private var shotsListCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BERECHNETE FOKUSPUNKTE (\(currentShots.count))")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppSettings.secondaryText)
                .tracking(0.8)

            ForEach(currentShots) { shot in
                HStack {
                    ZStack {
                        Circle()
                            .fill(AppSettings.controlBackground)
                            .frame(width: 28, height: 28)
                        Text("\(shot.index)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppSettings.accentAmber)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fokus: \(settings.formattedDistance(shot.focusDistanceM))")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppSettings.primaryText)

                        let farStr = shot.farLimitM == nil ? "∞" : settings.formattedDistance(shot.farLimitM!)
                        Text("Scharf von \(settings.formattedDistance(shot.nearLimitM)) bis \(farStr)")
                            .font(.system(size: 12))
                            .foregroundColor(AppSettings.secondaryText)
                    }

                    Spacer()
                }
                .padding(.vertical, 6)

                if shot.id != currentShots.last?.id {
                    Divider().background(AppSettings.border.opacity(0.6))
                }
            }
        }
        .padding(18)
        .background(AppSettings.cardBackground)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppSettings.border, lineWidth: 1))
    }
}

// MARK: - Szenengrafik mit überlappenden Bändern
public struct StackSceneGraphicView: View {
    public let shots: [StackShot]

    private var maxDist: Double {
        shots.last?.farLimitM ?? (shots.last?.focusDistanceM ?? 10) * 1.3
    }

    private func xPos(dist: Double, width: CGFloat) -> CGFloat {
        let norm = log10(1.0 + (dist / max(maxDist, 1.0)) * 9.0)
        return 20.0 + CGFloat(norm) * (width - 40.0)
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppSettings.cardBackgroundRaised)

                ForEach(shots) { shot in
                    let left = xPos(dist: shot.nearLimitM, width: w)
                    let right = shot.farLimitM == nil ? (w - 10) : min(w - 10, xPos(dist: shot.farLimitM!, width: w))
                    let bandWidth = max(4.0, right - left)
                    let alpha = 0.25 + 0.15 * Double(shot.index % 2)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppSettings.accentAmber.opacity(alpha))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppSettings.accentAmber.opacity(0.7), lineWidth: 1))
                        .frame(width: bandWidth, height: h * 0.45)
                        .position(x: left + bandWidth / 2.0, y: h * 0.45)

                    Circle()
                        .fill(AppSettings.primaryText)
                        .frame(width: 6, height: 6)
                        .position(x: xPos(dist: shot.focusDistanceM, width: w), y: h * 0.45)
                }
            }
        }
    }
}

// MARK: - Interaktive Stack-Checkliste Sheet
public struct StackChecklistSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let plan = settings.activeStackPlan {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(plan.completedCount) von \(plan.totalCount) aufgenommen · \(settings.formattedAperture(plan.aperture)) · \(Int(round(plan.focalLengthMM))) mm")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppSettings.secondaryText)

                        ProgressView(value: Double(plan.completedCount), total: Double(max(1, plan.totalCount)))
                            .tint(AppSettings.successMint)

                        Text("Stativ nicht bewegen, Blende beibehalten, nur den Fokusring drehen; beim nächsten Punkt beginnen.")
                            .font(.system(size: 11))
                            .foregroundColor(AppSettings.tertiaryText)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(AppSettings.cardBackground)

                    Divider().background(AppSettings.border)

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(0..<plan.shots.count, id: \.self) { idx in
                                let shot = plan.shots[idx]
                                Button(action: {
                                    toggleShot(at: idx)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Aufnahme \(shot.index)")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(shot.completed ? .black : AppSettings.secondaryText)

                                            Text("Fokus auf \(settings.formattedDistance(shot.focusDistanceM))")
                                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                                .foregroundColor(shot.completed ? .black : AppSettings.primaryText)

                                            let farStr = shot.farLimitM == nil ? "∞" : settings.formattedDistance(shot.farLimitM!)
                                            Text("Scharf von \(settings.formattedDistance(shot.nearLimitM)) bis \(farStr)")
                                                .font(.system(size: 11))
                                                .foregroundColor(shot.completed ? Color.black.opacity(0.7) : AppSettings.tertiaryText)
                                        }

                                        Spacer()

                                        Image(systemName: shot.completed ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 32))
                                            .foregroundColor(shot.completed ? .black : AppSettings.border)
                                    }
                                    .padding(18)
                                    .background(shot.completed ? AppSettings.successMint : AppSettings.cardBackground)
                                    .cornerRadius(18)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(shot.completed ? AppSettings.successMint : AppSettings.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                } else {
                    Text("Kein aktiver Stack-Plan vorhanden.")
                        .foregroundColor(AppSettings.secondaryText)
                        .padding()
                }
            }
            .background(AppSettings.appBackground.ignoresSafeArea())
            .navigationTitle("Stack-Checkliste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        if settings.activeStackPlan?.isFullyCompleted == true {
                            settings.recordSuccessfulAction()
                        }
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppSettings.accentAmber)
                }
            }
        }
    }

    private func toggleShot(at index: Int) {
        guard var plan = settings.activeStackPlan, index < plan.shots.count else { return }
        plan.shots[index].completed.toggle()
        if plan.isFullyCompleted {
            plan.completedAt = Date()
        } else {
            plan.completedAt = nil
        }
        settings.activeStackPlan = plan
    }
}

// MARK: - Share Sheet Helper
public struct ShareSheetView: UIViewControllerRepresentable {
    public let text: String

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
