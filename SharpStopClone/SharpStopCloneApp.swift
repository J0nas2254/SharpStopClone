//
//  SharpStopCloneApp.swift
//  FieldSharp (Clean-Room-Nachbau)
//
//  Zentraler App-Einstieg mit globaler Kopfleiste, Plan-Banner,
//  Nacht-UI Designsystem, Deep Linking und Tab-Navigation.
//

import SwiftUI

@main
struct SharpStopCloneApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var equipment = EquipmentManager()

    init() {
        // Tab-Bar Optik konfigurieren (Dunkles Nacht-Design)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0x0B/255.0, green: 0x0C/255.0, blue: 0x10/255.0, alpha: 1.0)
        appearance.shadowColor = UIColor(red: 0x38/255.0, green: 0x3B/255.0, blue: 0x43/255.0, alpha: 0.8)

        // Ausgewählter Tab: Amber
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0xEF/255.0, green: 0xB1/255.0, blue: 0x3C/255.0, alpha: 1.0)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0xEF/255.0, green: 0xB1/255.0, blue: 0x3C/255.0, alpha: 1.0),
            .font: UIFont.systemFont(ofSize: 10, weight: .bold)
        ]

        // Inaktiver Tab: Sekundärgrau
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(red: 0x74/255.0, green: 0x79/255.0, blue: 0x85/255.0, alpha: 1.0)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0x74/255.0, green: 0x79/255.0, blue: 0x85/255.0, alpha: 1.0),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    public var body: some Scene {
        WindowGroup {
            MainContainerView()
                .environmentObject(settings)
                .environmentObject(equipment)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    settings.handleDeepLink(url: url)
                }
        }
    }
}

// MARK: - Haupt-Container
public struct MainContainerView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var equipment: EquipmentManager

    public var body: some View {
        VStack(spacing: 0) {
            // Globale Kopfleiste
            GlobalHeaderView()

            // Dynamischer Plan-Banner
            PlanBannerView()

            // 5 Haupt-Tabs
            TabView(selection: $settings.selectedTab) {
                DepthOfFieldView()
                    .tabItem {
                        Label(AppTab.depth.title, systemImage: AppTab.depth.iconName)
                    }
                    .tag(AppTab.depth)

                FocusStackingView()
                    .tabItem {
                        Label(AppTab.stack.title, systemImage: AppTab.stack.iconName)
                    }
                    .tag(AppTab.stack)

                AstroView()
                    .tabItem {
                        Label(AppTab.stars.title, systemImage: AppTab.stars.iconName)
                    }
                    .tag(AppTab.stars)

                NDView()
                    .tabItem {
                        Label(AppTab.nd.title, systemImage: AppTab.nd.iconName)
                    }
                    .tag(AppTab.nd)

                FieldOfViewView()
                    .tabItem {
                        Label(AppTab.fov.title, systemImage: AppTab.fov.iconName)
                    }
                    .tag(AppTab.fov)
            }
        }
        .background(AppSettings.appBackground.ignoresSafeArea())
        .sheet(isPresented: $settings.showingReferenceSheet) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(equipment)
        }
        .sheet(isPresented: $settings.showingOnboarding) {
            OnboardingView()
                .environmentObject(settings)
        }
    }
}

// MARK: - Globale Kopfleiste
public struct GlobalHeaderView: View {
    @EnvironmentObject var settings: AppSettings

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // App-Titel & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text("FIELDSHARP")
                    .font(.system(size: 19, weight: .black, design: .default))
                    .foregroundColor(AppSettings.primaryText)
                    .tracking(1.5)

                Text("DIE SCHARFE AUFNAHME PLANEN")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppSettings.tertiaryText)
                    .tracking(1.0)
            }

            Spacer()

            // M | FT Umschalter
            HStack(spacing: 0) {
                Button(action: { settings.useImperialUnits = false }) {
                    Text("M")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 30, height: 26)
                        .background(!settings.useImperialUnits ? AppSettings.accentAmber : Color.clear)
                        .foregroundColor(!settings.useImperialUnits ? .black : AppSettings.secondaryText)
                }

                Button(action: { settings.useImperialUnits = true }) {
                    Text("FT")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 30, height: 26)
                        .background(settings.useImperialUnits ? AppSettings.accentAmber : Color.clear)
                        .foregroundColor(settings.useImperialUnits ? .black : AppSettings.secondaryText)
                }
            }
            .background(AppSettings.controlBackground)
            .cornerRadius(13)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppSettings.border, lineWidth: 1))

            // Ellipsis Mehr-Button
            Button(action: {
                settings.showingReferenceSheet = true
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(AppSettings.controlBackground)
                    .foregroundColor(AppSettings.primaryText)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppSettings.border, lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(AppSettings.appBackground)
    }
}

// MARK: - Dynamischer Plan-Banner
public struct PlanBannerView: View {
    @EnvironmentObject var settings: AppSettings

    private var tonightPlan: MilkyWayNightPlan {
        analyzeMilkyWayNight(
            nightDate: Date(),
            latitude: settings.selectedPlace.latitude,
            longitude: settings.selectedPlace.longitude,
            timeZone: settings.selectedPlace.timeZone
        )
    }

    public var body: some View {
        // Priorität 1: Unvollendeter Fokus-Stack
        if let stack = settings.activeStackPlan, !stack.isFullyCompleted {
            let remaining = stack.totalCount - stack.completedCount
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.down.right.fill")
                    .foregroundColor(AppSettings.accentAmber)
                    .font(.system(size: 14))

                Text("\(stack.totalCount) Aufnahmen · \(remaining) noch offen")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppSettings.primaryText)

                Spacer()

                Button("Fortsetzen ›") {
                    settings.selectedTab = .stack
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppSettings.accentAmber)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppSettings.cardBackgroundRaised)
            .overlay(Rectangle().frame(height: 1).foregroundColor(AppSettings.border), alignment: .bottom)
        }
        // Priorität 2: Milchstraßenfenster heute Nacht
        else if tonightPlan.isVisible, let s = tonightPlan.windowStart, let e = tonightPlan.windowEnd {
            let tf: DateFormatter = {
                let f = DateFormatter()
                f.timeZone = settings.selectedPlace.timeZone
                f.dateFormat = "HH:mm"
                return f
            }()
            let startStr = tf.string(from: s)
            let endStr = tf.string(from: e)

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundColor(AppSettings.accentAmber)
                    .font(.system(size: 14))

                Text("Heute Nacht \(startStr)–\(endStr) · Zentrum sichtbar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppSettings.primaryText)

                Spacer()

                Button("Plan ›") {
                    settings.selectedTab = .stars
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppSettings.accentAmber)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppSettings.cardBackgroundRaised)
            .overlay(Rectangle().frame(height: 1).foregroundColor(AppSettings.border), alignment: .bottom)
        }
    }
}
