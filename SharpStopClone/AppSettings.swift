//
//  AppSettings.swift
//  FieldSharp (Clean-Room-Nachbau)
//

import Foundation
import SwiftUI
import Combine
import StoreKit

public enum AppTab: Int, CaseIterable, Identifiable {
    case depth = 0
    case stack = 1
    case stars = 2
    case nd = 3
    case fov = 4

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .depth: return "Schärfe"
        case .stack: return "Stack"
        case .stars: return "Sterne"
        case .nd:    return "ND"
        case .fov:   return "Bildfeld"
        }
    }

    public var iconName: String {
        switch self {
        case .depth: return "scope"
        case .stack: return "square.stack.3d.down.right.fill"
        case .stars: return "sparkles"
        case .nd:    return "circle.lefthalf.filled"
        case .fov:   return "viewfinder"
        }
    }
}

public final class AppSettings: ObservableObject {
    // MARK: - Global Design System Farbtöne
    public static let appBackground = Color(red: 0x0B/255.0, green: 0x0C/255.0, blue: 0x10/255.0)
    public static let cardBackground = Color(red: 0x17/255.0, green: 0x17/255.0, blue: 0x1B/255.0)
    public static let cardBackgroundRaised = Color(red: 0x20/255.0, green: 0x21/255.0, blue: 0x27/255.0)
    public static let controlBackground = Color(red: 0x27/255.0, green: 0x28/255.0, blue: 0x2E/255.0)
    public static let border = Color(red: 0x38/255.0, green: 0x3B/255.0, blue: 0x43/255.0)
    public static let primaryText = Color(red: 0xEC/255.0, green: 0xEE/255.0, blue: 0xF0/255.0)
    public static let secondaryText = Color(red: 0x96/255.0, green: 0x9B/255.0, blue: 0xA6/255.0)
    public static let tertiaryText = Color(red: 0x74/255.0, green: 0x79/255.0, blue: 0x85/255.0)
    public static let accentAmber = Color(red: 0xEF/255.0, green: 0xB1/255.0, blue: 0x3C/255.0)
    public static let successMint = Color(red: 0x66/255.0, green: 0xCF/255.0, blue: 0x96/255.0)
    public static let warningCoral = Color(red: 0xED/255.0, green: 0x78/255.0, blue: 0x5A/255.0)
    public static let chartBlue = Color(red: 0x55/255.0, green: 0x5F/255.0, blue: 0x82/255.0)

    // MARK: - Einheiten
    @Published public var useImperialUnits: Bool = UserDefaults.standard.bool(forKey: "use_imperial") {
        didSet { UserDefaults.standard.set(useImperialUnits, forKey: "use_imperial") }
    }

    // MARK: - Navigation
    @Published public var selectedTab: AppTab = .depth
    @Published public var showingReferenceSheet: Bool = false
    @Published public var showingChecklistSheet: Bool = false
    @Published public var showingBestNightsSheet: Bool = false
    @Published public var showingNightLogsSheet: Bool = false
    @Published public var showingGlossarySheet: Bool = false
    @Published public var showingEquipmentSheet: Bool = false
    @Published public var activeGlossaryTerm: GlossaryTerm? = nil
    @Published public var hasSeenOnboarding: Bool = UserDefaults.standard.bool(forKey: "has_seen_onboarding") {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: "has_seen_onboarding") }
    }
    @Published public var showingOnboarding: Bool = false

    // MARK: - Geteilte Aufnahmeparameter
    @Published public var focalLength: Double = 50.0
    @Published public var aperture: Double = 2.8
    @Published public var subjectDistance: Double = 5.0 // Meter

    // MARK: - Aktiver Fokus-Stack Plan
    @Published public var activeStackPlan: FocusStackPlan? {
        didSet { saveActiveStackPlan() }
    }

    // MARK: - Astronomie Orte & Datum
    @Published public var places: [Place] = [] {
        didSet { savePlaces() }
    }
    @Published public var selectedPlace: Place = Place.builtInPlaces.first!
    @Published public var selectedAstroDate: Date = Date()

    // MARK: - Nacht-Logbuch
    @Published public var nightLogs: [NightLogEntry] = [] {
        didSet { saveNightLogs() }
    }

    // MARK: - Review Prompts
    private var actionSuccessCount: Int = UserDefaults.standard.integer(forKey: "action_success_count")

    public init() {
        loadPlaces()
        loadActiveStackPlan()
        loadNightLogs()

        if !hasSeenOnboarding {
            showingOnboarding = true
        }
    }

    // MARK: - Formatierungshelfer
    public func formattedDistance(_ meters: Double) -> String {
        SharpStopClone.formattedDistance(meters, useImperial: useImperialUnits)
    }

    public func formattedFocalLength(_ mm: Double) -> String {
        "\(Int(round(mm))) mm"
    }

    public func formattedAperture(_ ap: Double) -> String {
        if ap == floor(ap) {
            return "f/\(Int(ap))"
        } else {
            return String(format: "f/%.1f", ap)
        }
    }

    // MARK: - Persistence Methoden
    private func saveActiveStackPlan() {
        if let plan = activeStackPlan, let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: "active_stack_plan")
        } else {
            UserDefaults.standard.removeObject(forKey: "active_stack_plan")
        }
    }

    private func loadActiveStackPlan() {
        if let data = UserDefaults.standard.data(forKey: "active_stack_plan"),
           let plan = try? JSONDecoder().decode(FocusStackPlan.self, from: data) {
            self.activeStackPlan = plan
        }
    }

    private func savePlaces() {
        if let data = try? JSONEncoder().encode(places) {
            UserDefaults.standard.set(data, forKey: "saved_places")
        }
    }

    private func loadPlaces() {
        if let data = UserDefaults.standard.data(forKey: "saved_places"),
           let decoded = try? JSONDecoder().decode([Place].self, from: data),
           !decoded.isEmpty {
            self.places = decoded
        } else {
            self.places = Place.builtInPlaces
        }
        self.selectedPlace = self.places.first ?? Place.builtInPlaces.first!
    }

    public func addCustomPlace(_ place: Place) {
        places.append(place)
        selectedPlace = place
    }

    private func saveNightLogs() {
        if let data = try? JSONEncoder().encode(nightLogs) {
            UserDefaults.standard.set(data, forKey: "saved_night_logs")
        }
    }

    private func loadNightLogs() {
        if let data = UserDefaults.standard.data(forKey: "saved_night_logs"),
           let decoded = try? JSONDecoder().decode([NightLogEntry].self, from: data) {
            self.nightLogs = decoded
        }
    }

    public func addNightLog(_ log: NightLogEntry) {
        nightLogs.insert(log, at: 0)
        recordSuccessfulAction()
    }

    public func deleteNightLog(at offsets: IndexSet) {
        nightLogs.remove(atOffsets: offsets)
    }

    public func recordSuccessfulAction() {
        actionSuccessCount += 1
        UserDefaults.standard.set(actionSuccessCount, forKey: "action_success_count")
        if actionSuccessCount == 3 || actionSuccessCount == 10 {
            requestReviewIfAppropriate()
        }
    }

    public func requestReviewIfAppropriate() {
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }

    // MARK: - Deep Linking
    public func handleDeepLink(url: URL) {
        guard url.scheme == "fieldsharp" else { return }
        switch url.host {
        case "depth":
            selectedTab = .depth
        case "stack":
            selectedTab = .stack
        case "stars":
            selectedTab = .stars
            if url.path == "/best-nights" {
                showingBestNightsSheet = true
            }
        case "nd":
            selectedTab = .nd
        case "field-of-view":
            selectedTab = .fov
        case "equipment":
            showingEquipmentSheet = true
        case "reference":
            showingReferenceSheet = true
        default:
            break
        }
    }
}

// MARK: - Vollständiges Glossar
public struct GlossaryTerm: Identifiable, Hashable {
    public var id: String { term }
    public let term: String
    public let definition: String
    public let category: String

    public init(term: String, definition: String, category: String) {
        self.term = term
        self.definition = definition
        self.category = category
    }
}

public struct Glossary {
    public static let terms: [GlossaryTerm] = [
        GlossaryTerm(
            term: "Blende",
            definition: "Die variable Öffnung im Objektiv, die die einfallende Lichtmenge und die Schärfentiefe steuert. Kleinere Blendenzahlen (z. B. f/1.8) bedeuten eine größere Öffnung und geringere Schärfentiefe.",
            category: "Optik"
        ),
        GlossaryTerm(
            term: "Brennweite",
            definition: "Der Abstand zwischen der optischen Hauptebene des Objektivs und dem Sensor im Fokus. Kürzere Brennweiten bieten einen weiten Bildwinkel, längere vergrößern weit entfernte Motive.",
            category: "Optik"
        ),
        GlossaryTerm(
            term: "Fokusdistanz",
            definition: "Der gemessene Abstand von der Sensorebene der Kamera bis zum exakt fokussierten Motiv.",
            category: "Schärfe"
        ),
        GlossaryTerm(
            term: "Schärfentiefe",
            definition: "Der Raum vor und hinter der fokussierten Motivebene, der für das menschliche Auge bei normaler Betrachtung als scharf wahrgenommen wird.",
            category: "Schärfe"
        ),
        GlossaryTerm(
            term: "Nahgrenze",
            definition: "Der der Kamera am nächsten liegende Abstand, an dem Motive noch akzeptabel scharf wiedergegeben werden.",
            category: "Schärfe"
        ),
        GlossaryTerm(
            term: "Ferngrenze",
            definition: "Der fernste Abstand, bis zu dem Motive scharf erscheinen. Liegt das Motiv bei oder hinter der Hyperfokaldistanz, wird die Ferngrenze unendlich.",
            category: "Schärfe"
        ),
        GlossaryTerm(
            term: "Schärfebereich vor / hinter Motiv",
            definition: "Die reale Verteilung der Schärfe vor und hinter dem Fokuspunkt. Im Nahbereich teilt sie sich oft annähernd 50:50, mit zunehmender Entfernung verschiebt sie sich weit nach hinten.",
            category: "Schärfe"
        ),
        GlossaryTerm(
            term: "Zerstreuungskreis (CoC)",
            definition: "Der maximale Unschärfepunkt auf dem Sensor, der bei normaler Vergrößerung noch als einzelner scharfer Punkt wahrgenommen wird. FieldSharp berechnet c exakt als Sensordiagonale / 1500.",
            category: "Optik"
        ),
        GlossaryTerm(
            term: "Hyperfokaldistanz",
            definition: "Die kürzeste Fokusdistanz, bei der die Schärfentiefe bis unendlich reicht. Fokussierst du genau auf H, ist alles von der halben Hyperfokaldistanz (H/2) bis unendlich akzeptabel scharf.",
            category: "Schärfe"
        ),
        GlossaryTerm(
            term: "Fokus-Stacking",
            definition: "Aufnahmetechnik, bei der mehrere Bilder mit minimal versetzten Fokusebenen geschossen und in der Nachbearbeitung zusammengerechnet werden, um eine durchgehende Schärfe zu erzielen.",
            category: "Stacking"
        ),
        GlossaryTerm(
            term: "Überlappung",
            definition: "Der Sicherheitsabstand zwischen zwei benachbarten Schärfebereichen beim Stacking. FieldSharp nutzt standardmäßig 15 %, um Unschärfelücken sicher zu verhindern.",
            category: "Stacking"
        ),
        GlossaryTerm(
            term: "Astronomische Dunkelheit",
            definition: "Der Zeitraum, in dem die Sonne tiefer als 18 Grad unter dem Horizont steht. Erst dann stört kein diffuses Himmelslicht mehr die Astrofotografie.",
            category: "Astro"
        ),
        GlossaryTerm(
            term: "Galaktisches Zentrum",
            definition: "Das helle, sternenreiche Kernzentrum unserer Milchstraße im Sternbild Schütze (RA 266,42°, Dec -29,01°).",
            category: "Astro"
        ),
        GlossaryTerm(
            term: "Mondbeleuchtung",
            definition: "Der von der Sonne beleuchtete sichtbare Prozentsatz der Mondoberfläche. Bei Neumond (0 %) ist der Nachthimmel am dunkelsten.",
            category: "Astro"
        ),
        GlossaryTerm(
            term: "Azimut / Richtung",
            definition: "Die Himmelsrichtung entlang des Horizonts, gemessen im Uhrzeigersinn von Norden (0° = N, 90° = O, 180° = S, 270° = W).",
            category: "Astro"
        ),
        GlossaryTerm(
            term: "NPF-Regel",
            definition: "Präzise Formel zur Bestimmung der maximalen Belichtungszeit für punktförmige Sterne ohne Strichspuren: t = (35·N + 30·p) / f. Berücksichtigt Blende, Sensor-Pixelabstand und Brennweite.",
            category: "Astro"
        ),
        GlossaryTerm(
            term: "500er-Regel",
            definition: "Traditionelle Faustformel für Kleinbildfilm: 500 / (Brennweite × Crop-Faktor). Auf modernen, hochauflösenden Sensoren führt sie häufig zu sichtbaren Sternspuren.",
            category: "Astro"
        ),
        GlossaryTerm(
            term: "Pixelabstand / Pixelpitch",
            definition: "Der Abstand zwischen den Mittelpunkten zweier benachbarter lichtempfindlicher Pixel auf dem Sensor, angegeben in Mikrometern (µm).",
            category: "Optik"
        ),
        GlossaryTerm(
            term: "ND-Blendenstufe",
            definition: "Lichtreduzierende Stärke eines Neutraldichtefilters. Jede Stufe verdoppelt die erforderliche Belichtungszeit.",
            category: "Filter"
        ),
        GlossaryTerm(
            term: "Optische Dichte",
            definition: "Logarithmisches Maß der Lichtabsorption eines ND-Filters. Berechnet sich als 0,3 × Blendenstufen (z. B. 10 Stufen = ND 3,0).",
            category: "Filter"
        ),
        GlossaryTerm(
            term: "ND-Faktor",
            definition: "Der Verlängerungsfaktor der Belichtungszeit (2^Stufen). Ein 10-Stufen-Filter entspricht ND1024.",
            category: "Filter"
        ),
        GlossaryTerm(
            term: "Bildwinkel / Bildfeld",
            definition: "Der durch Sensorgröße und Brennweite festgelegte sichtbare Winkel und die entsprechende reale Ausschnittsbreite und -höhe am fokussierten Motiv.",
            category: "Bildfeld"
        )
    ]
}
