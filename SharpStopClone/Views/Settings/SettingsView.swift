//
//  SettingsView.swift
//  FieldSharp (Clean-Room-Nachbau)
//
//  Mehr-Menü / Referenz, Glossar, Onboarding, Feedback, NDView und FieldOfViewView
//

import SwiftUI
import StoreKit
import CoreGraphics

// MARK: - Mehr- / Referenz-Sheet
public struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var equipment: EquipmentManager

    @State private var showingFeedbackSheet = false
    @State private var showingAboutSheet = false

    private var activeCamera: CameraBody {
        equipment.selectedCamera ?? equipment.cameras.first ?? CameraBody(name: "Vollformat", sensorFormat: .fullFrame)
    }

    private var activeLens: Lens {
        equipment.selectedLens ?? equipment.lenses.first ?? Lens(name: "Standard", isZoom: false, minFocalLengthMM: 50, maxFocalLengthMM: 50, maxApertureWide: 1.8, sensorFormat: .fullFrame)
    }

    public var body: some View {
        NavigationStack {
            List {
                // Sektion Werkzeuge & Referenz
                Section(header: Text("WERKZEUGE & REFERENZ").foregroundColor(AppSettings.secondaryText)) {
                    Button(action: { settings.showingEquipmentSheet = true }) {
                        Label("Ausrüstung verwalten", systemImage: "camera")
                            .foregroundColor(AppSettings.primaryText)
                    }

                    Button(action: { settings.showingGlossarySheet = true }) {
                        Label("Glossar & Begriffe", systemImage: "book")
                            .foregroundColor(AppSettings.primaryText)
                    }

                    Button(action: { settings.showingNightLogsSheet = true }) {
                        Label("Nacht-Logbuch", systemImage: "sparkles")
                            .foregroundColor(AppSettings.primaryText)
                    }
                }
                .listRowBackground(AppSettings.cardBackground)

                // Sektion Einstellungen
                Section(header: Text("EINSTELLUNGEN").foregroundColor(AppSettings.secondaryText)) {
                    Toggle(isOn: $settings.useImperialUnits) {
                        Label("Imperiale Einheiten (ft / in)", systemImage: "ruler")
                            .foregroundColor(AppSettings.primaryText)
                    }
                    .tint(AppSettings.accentAmber)

                    Button(action: {
                        dismiss()
                        settings.showingOnboarding = true
                    }) {
                        Label("Einführung erneut ansehen", systemImage: "sparkles.rectangle.stack")
                            .foregroundColor(AppSettings.primaryText)
                    }
                }
                .listRowBackground(AppSettings.cardBackground)

                // Sektion Feedback & Bewertung
                Section(header: Text("FEEDBACK & BEWERTUNG").foregroundColor(AppSettings.secondaryText)) {
                    Button(action: { showingFeedbackSheet = true }) {
                        Label("Feedback geben / Problem melden", systemImage: "envelope")
                            .foregroundColor(AppSettings.primaryText)
                    }

                    Button(action: {
                        settings.requestReviewIfAppropriate()
                    }) {
                        Label("FieldSharp bewerten", systemImage: "star")
                            .foregroundColor(AppSettings.accentAmber)
                    }
                }
                .listRowBackground(AppSettings.cardBackground)

                // Sektion Rechtliches & Info
                Section(header: Text("INFO & GRENZEN").foregroundColor(AppSettings.secondaryText)) {
                    Button(action: { showingAboutSheet = true }) {
                        Label("Über FieldSharp & Grenzen der App", systemImage: "info.circle")
                            .foregroundColor(AppSettings.primaryText)
                    }

                    HStack {
                        Label("100 % Offline & Privat", systemImage: "lock.shield")
                            .foregroundColor(AppSettings.secondaryText)
                        Spacer()
                        Text("Kein Tracking")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppSettings.successMint)
                    }
                }
                .listRowBackground(AppSettings.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppSettings.appBackground.ignoresSafeArea())
            .navigationTitle("Referenz & Mehr")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .foregroundColor(AppSettings.accentAmber)
                }
            }
            .sheet(isPresented: $showingFeedbackSheet) {
                FeedbackSheetView()
            }
            .sheet(isPresented: $showingAboutSheet) {
                AboutSheetView()
            }
            .sheet(isPresented: $settings.showingGlossarySheet) {
                GlossarySheetView()
            }
            .sheet(isPresented: $settings.showingEquipmentSheet) {
                EquipmentView()
            }
        }
    }
}

// MARK: - Glossar Sheet
public struct GlossarySheetView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    private var filteredTerms: [GlossaryTerm] {
        if searchText.isEmpty {
            return Glossary.terms
        }
        return Glossary.terms.filter {
            $0.term.localizedCaseInsensitiveContains(searchText) ||
            $0.definition.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(filteredTerms) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.term)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppSettings.accentAmber)
                            Spacer()
                            Text(item.category)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppSettings.controlBackground)
                                .foregroundColor(AppSettings.secondaryText)
                                .cornerRadius(6)
                        }

                        Text(item.definition)
                            .font(.system(size: 13))
                            .foregroundColor(AppSettings.primaryText)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(AppSettings.cardBackground)
                }
            }
            .searchable(text: $searchText, prompt: "Begriff suchen …")
            .scrollContentBackground(.hidden)
            .background(AppSettings.appBackground.ignoresSafeArea())
            .navigationTitle("Optik-Glossar")
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

// MARK: - Über FieldSharp Sheet
public struct AboutSheetView: View {
    @Environment(\.dismiss) var dismiss

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 48))
                            .foregroundColor(AppSettings.accentAmber)
                        Text("FieldSharp")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppSettings.primaryText)
                        Text("Version 1.0.0 (Clean-Room-Nachbau)")
                            .font(.system(size: 12))
                            .foregroundColor(AppSettings.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("GRENZEN DER SCHÄRFENTIEFE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppSettings.accentAmber)

                        Text("Schärfentiefe ist ein Akzeptanzmaß für einen normal großen Abzug unter typischem Betrachtungsabstand und keine harte physikalische Kante. In 100-%-Ansichten am Bildschirm oder bei extremen Crops wirken die Grenzen weicher. Beugungsunschärfe bei geschlossener Blende (f/16, f/22) wird im geometrischen Schärfentiefemodell nicht berücksichtigt.")
                            .font(.system(size: 13))
                            .foregroundColor(AppSettings.primaryText)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .background(AppSettings.cardBackground)
                    .cornerRadius(16)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("DATENSCHUTZVERSPRECHEN")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppSettings.successMint)

                        Text("FieldSharp funktioniert 100 % lokal und offline. Die App nutzt weder Accounts noch externe Analyse- oder Werbedienste. Sämtliche Optik- und Astronomieberechnungen erfolgen direkt auf deinem Gerät.")
                            .font(.system(size: 13))
                            .foregroundColor(AppSettings.primaryText)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .background(AppSettings.cardBackground)
                    .cornerRadius(16)
                }
                .padding(20)
            }
            .background(AppSettings.appBackground.ignoresSafeArea())
            .navigationTitle("Über FieldSharp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundColor(AppSettings.accentAmber)
                }
            }
        }
    }
}

// MARK: - Feedback Sheet mit Mailto Fallback
public struct FeedbackSheetView: View {
    @Environment(\.dismiss) var dismiss

    @State private var category = "Verbesserungsvorschlag"
    @State private var message = ""
    @State private var email = ""

    private let categories = ["Verbesserungsvorschlag", "Problem / Bug", "Ausrüstungswunsch", "Sonstiges"]

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Kategorie")) {
                    Picker("Art des Feedbacks", selection: $category) {
                        ForEach(categories, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                }

                Section(header: Text("Deine Nachricht")) {
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                }

                Section(header: Text("Optionale Rückmelde-E-Mail")) {
                    TextField("deine@email.de", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section(footer: Text("Beim Absenden öffnet sich dein Standard-Mailprogramm mit vorformuliertem Text und Versionsdaten.")) {
                    Button(action: sendMail) {
                        Text("Feedback per E-Mail absenden")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .foregroundColor(AppSettings.accentAmber)
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Feedback & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    private func sendMail() {
        let subject = "FieldSharp Feedback: \(category)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let bodyText = """
        Kategorie: \(category)
        Kontakt: \(email)

        Nachricht:
        \(message)

        ---
        App: FieldSharp 1.0.0
        System: iOS \(UIDevice.current.systemVersion)
        Gerät: \(UIDevice.current.model)
        """
        let body = bodyText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:support@fieldsharp.app?subject=\(subject)&body=\(body)") {
            UIApplication.shared.open(url)
        }
        dismiss()
    }
}

// MARK: - 4-Stufiges Onboarding
public struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    @State private var currentStep = 0

    public var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button("Überspringen") {
                    completeOnboarding()
                }
                .font(.system(size: 14))
                .foregroundColor(AppSettings.secondaryText)
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)

            TabView(selection: $currentStep) {
                stepView(
                    icon: "scope",
                    title: "Was wird scharf?",
                    text: "Erfahre auf den Zentimeter genau, wo die Schärfentiefe beginnt und endet. Nutze die Hyperfokaldistanz für maximale Tiefe bis zum Horizont.",
                    stepIndex: 0
                )
                .tag(0)

                stepView(
                    icon: "square.stack.3d.down.right.fill",
                    title: "Stacks und Sterne planen",
                    text: "Plane präzise Fokus-Stacks mit Überlappung und hake Aufnahmen direkt vor Ort am Stativ ab. Plane den perfekten Moment für den Milchstraßenkern.",
                    stepIndex: 1
                )
                .tag(1)

                stepView(
                    icon: "lock.shield.fill",
                    title: "100 % offline & privat",
                    text: "Keine Accounts, keine Cloud, kein Tracking. Alle Berechnungen laufen rein physikalisch auf deinem iPhone – verlässlich auch im tiefen Gebirge.",
                    stepIndex: 2
                )
                .tag(2)

                setupStepView()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            // Weiter / Loslegen Button
            Button(action: {
                if currentStep < 3 {
                    withAnimation { currentStep += 1 }
                } else {
                    completeOnboarding()
                }
            }) {
                Text(currentStep == 3 ? "Loslegen" : "Weiter")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppSettings.accentAmber)
                    .foregroundColor(.black)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(AppSettings.appBackground.ignoresSafeArea())
    }

    private func stepView(icon: String, title: String, text: String, stepIndex: Int) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(AppSettings.accentAmber)

            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppSettings.primaryText)
                .multilineTextAlignment(.center)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(AppSettings.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 20)

            Spacer()
        }
        .padding(20)
    }

    private func setupStepView() -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 64))
                .foregroundColor(AppSettings.accentAmber)

            Text("Grundeinrichtung")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppSettings.primaryText)

            Text("Wähle dein bevorzugtes Einheitensystem. Du kannst es jederzeit in der Kopfleiste umschalten.")
                .font(.system(size: 14))
                .foregroundColor(AppSettings.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            HStack(spacing: 16) {
                unitChoiceButton(title: "Metrisch (m / cm)", isImperial: false)
                unitChoiceButton(title: "Imperial (ft / in)", isImperial: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer()
        }
        .padding(20)
    }

    private func unitChoiceButton(title: String, isImperial: Bool) -> some View {
        Button(action: {
            settings.useImperialUnits = isImperial
        }) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(settings.useImperialUnits == isImperial ? AppSettings.accentAmber : AppSettings.controlBackground)
                .foregroundColor(settings.useImperialUnits == isImperial ? .black : AppSettings.primaryText)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(settings.useImperialUnits == isImperial ? AppSettings.accentAmber : AppSettings.border, lineWidth: 1))
        }
    }

    private func completeOnboarding() {
        settings.hasSeenOnboarding = true
        settings.showingOnboarding = false
        dismiss()
    }
}

// MARK: - Tab 4: NDView
public struct NDView: View {
    @EnvironmentObject var settings: AppSettings

    @State private var baseTimeSeconds: Double = 1.0 / 250.0
    @State private var stops: Int = 10

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
                resultCard
                filterStrengthCard
                baseShutterCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppSettings.appBackground.ignoresSafeArea())
    }

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

            HStack(spacing: 8) {
                filterPresetButton(label: "3 Stufen (ND8)", value: 3)
                filterPresetButton(label: "6 Stufen (ND64)", value: 6)
                filterPresetButton(label: "10 Stufen (ND1000)", value: 10)
                filterPresetButton(label: "15 Stufen", value: 15)
            }

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

// MARK: - Tab 5: FieldOfViewView
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

    private var horizAOVdeg: Double {
        radToDeg(horizontalFOV(sensorWidthMM: camera.sensorFormat.sensorWidthMM, focalLength: focalLength))
    }

    private var vertAOVdeg: Double {
        radToDeg(verticalFOV(sensorHeightMM: camera.sensorFormat.sensorHeightMM, focalLength: focalLength))
    }

    private var diagAOVdeg: Double {
        radToDeg(diagonalFOV(sensorWidthMM: camera.sensorFormat.sensorWidthMM, sensorHeightMM: camera.sensorFormat.sensorHeightMM, focalLength: focalLength))
    }

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
                resultCard
                parametersCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppSettings.appBackground.ignoresSafeArea())
    }

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

            FieldFrameGraphicView(
                fieldWidthM: fieldWidthM,
                fieldHeightM: fieldHeightM
            )
            .frame(height: 160)
            .padding(.vertical, 4)

            HStack(spacing: 8) {
                metricColumn(title: "FELD-BREITE", value: settings.formattedDistance(fieldWidthM), isAccent: true)
                Divider().background(AppSettings.border)
                metricColumn(title: "FELD-HÖHE", value: settings.formattedDistance(fieldHeightM), isAccent: true)
            }
            .padding(.vertical, 8)
            .background(AppSettings.cardBackgroundRaised.cornerRadius(12))

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

    private var parametersCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("PARAMETER")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppSettings.secondaryText)
                .tracking(0.8)

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

    private func frameRect(for size: CGSize) -> CGRect {
        let w = size.width
        let h = size.height
        let frameAspect = (fieldWidthM > 0 && fieldHeightM > 0) ? CGFloat(fieldWidthM / fieldHeightM) : CGFloat(1.5)

        var rectW = w * 0.85
        var rectH = rectW / frameAspect
        if rectH > h * 0.85 {
            rectH = h * 0.85
            rectW = rectH * frameAspect
        }
        return CGRect(x: (w - rectW) / 2.0, y: (h - rectH) / 2.0, width: rectW, height: rectH)
    }

    private func personHeight(for rectH: CGFloat) -> CGFloat {
        let personHeightM = 1.75
        let personFrac = CGFloat(min(1.0, max(0.05, personHeightM / max(0.1, fieldHeightM))))
        return min(rectH * 0.95, rectH * personFrac)
    }

    public var body: some View {
        GeometryReader { geo in
            let rect = frameRect(for: geo.size)
            let renderedPersonH = personHeight(for: rect.height)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppSettings.cardBackgroundRaised)

                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppSettings.accentAmber, lineWidth: 1.5)
                    .frame(width: rect.width, height: rect.height)

                Path { p in
                    let arm: CGFloat = 10.0
                    p.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
                    p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                    p.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))

                    p.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))

                    p.move(to: CGPoint(x: rect.minX, y: rect.maxY - arm))
                    p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                    p.addLine(to: CGPoint(x: rect.minX + arm, y: rect.maxY))

                    p.move(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
                }
                .stroke(AppSettings.accentAmber, lineWidth: 2.5)

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
