//
//  EquipmentView.swift
//  FieldSharp (Clean-Room-Nachbau)
//
//  Ausrüstungsverwaltung: Kameras & Objektive
//

import SwiftUI

public struct EquipmentView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var equipment: EquipmentManager
    @EnvironmentObject var settings: AppSettings

    @State private var showingAddCamera = false
    @State private var showingAddLens = false
    @State private var cameraToEdit: CameraBody? = nil
    @State private var lensToEdit: Lens? = nil

    public var body: some View {
        NavigationStack {
            List {
                // MARK: - Kameras
                Section {
                    ForEach(equipment.cameras) { cam in
                        let isSelected = (equipment.selectedCamera?.id == cam.id)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(cam.name)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(AppSettings.primaryText)
                                    if isSelected {
                                        Text("AKTIV")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(AppSettings.accentAmber)
                                            .foregroundColor(.black)
                                            .cornerRadius(6)
                                    }
                                }

                                Text("\(cam.sensorFormat.displayName) · \(Int(round(cam.megapixels))) MP · c = \(String(format: "%.4f", cam.circleOfConfusionMM)) mm")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppSettings.secondaryText)
                            }

                            Spacer()

                            Button(action: {
                                cameraToEdit = cam
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(AppSettings.secondaryText)
                            }
                            .buttonStyle(.borderless)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            equipment.selectedCamera = cam
                        }
                        .listRowBackground(AppSettings.cardBackground)
                    }
                    .onDelete(perform: equipment.removeCamera)

                    Button(action: { showingAddCamera = true }) {
                        Label("Kamera hinzufügen", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppSettings.accentAmber)
                    }
                    .listRowBackground(AppSettings.cardBackground)
                } header: {
                    Text("KAMERAGEHÄUSE")
                        .foregroundColor(AppSettings.secondaryText)
                }

                // MARK: - Objektive
                Section {
                    ForEach(equipment.lenses) { lens in
                        let isSelected = (equipment.selectedLens?.id == lens.id)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(lens.name)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(AppSettings.primaryText)
                                    if isSelected {
                                        Text("AKTIV")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(AppSettings.accentAmber)
                                            .foregroundColor(.black)
                                            .cornerRadius(6)
                                    }
                                }

                                Text("\(lens.focalLengthDisplay) · \(lens.apertureDisplay) · Nahgrenze: \(settings.formattedDistance(lens.minimumFocusDistanceM))")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppSettings.secondaryText)
                            }

                            Spacer()

                            Button(action: {
                                lensToEdit = lens
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(AppSettings.secondaryText)
                            }
                            .buttonStyle(.borderless)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            equipment.selectedLens = lens
                            settings.focalLength = equipment.clampFocalLength(settings.focalLength)
                            settings.aperture = equipment.clampAperture(settings.aperture, focalLength: settings.focalLength)
                            settings.subjectDistance = equipment.clampDistance(settings.subjectDistance)
                        }
                        .listRowBackground(AppSettings.cardBackground)
                    }
                    .onDelete(perform: equipment.removeLens)

                    Button(action: { showingAddLens = true }) {
                        Label("Objektiv hinzufügen", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppSettings.accentAmber)
                    }
                    .listRowBackground(AppSettings.cardBackground)
                } header: {
                    Text("OBJEKTIVE")
                        .foregroundColor(AppSettings.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppSettings.appBackground.ignoresSafeArea())
            .navigationTitle("Ausrüstung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppSettings.accentAmber)
                }
            }
            .sheet(isPresented: $showingAddCamera) {
                CameraEditorSheet(camera: nil) { newCam in
                    equipment.addCamera(newCam)
                }
            }
            .sheet(item: $cameraToEdit) { cam in
                CameraEditorSheet(camera: cam) { updated in
                    equipment.updateCamera(updated)
                }
            }
            .sheet(isPresented: $showingAddLens) {
                LensEditorSheet(lens: nil) { newLens in
                    equipment.addLens(newLens)
                }
            }
            .sheet(item: $lensToEdit) { l in
                LensEditorSheet(lens: l) { updated in
                    equipment.updateLens(updated)
                }
            }
        }
    }
}

// MARK: - Kamera Editor Sheet
public struct CameraEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    public let camera: CameraBody?
    public let onSave: (CameraBody) -> Void

    @State private var name: String = ""
    @State private var sensorFormat: SensorFormat = .fullFrame
    @State private var megapixelsStr: String = "33"

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Kamera Details")) {
                    TextField("Name / Modell", text: $name)
                    Picker("Sensorformat", selection: $sensorFormat) {
                        ForEach(SensorFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    TextField("Megapixel (z.B. 33)", text: $megapixelsStr)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .navigationTitle(camera == nil ? "Neue Kamera" : "Kamera bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let c = camera {
                    name = c.name
                    sensorFormat = c.sensorFormat
                    megapixelsStr = "\(Int(round(c.megapixels)))"
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let mp = Double(megapixelsStr.replacingOccurrences(of: ",", with: ".")) ?? 33.0
                        let cam = CameraBody(
                            id: camera?.id ?? UUID(),
                            name: name.isEmpty ? "Kamera" : name,
                            sensorFormat: sensorFormat,
                            megapixels: max(1.0, mp),
                            createdAt: camera?.createdAt ?? Date(),
                            updatedAt: Date()
                        )
                        onSave(cam)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Objektiv Editor Sheet
public struct LensEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    public let lens: Lens?
    public let onSave: (Lens) -> Void

    @State private var name: String = ""
    @State private var isZoom: Bool = false
    @State private var minFocalStr: String = "24"
    @State private var maxFocalStr: String = "70"
    @State private var apertureWideStr: String = "2.8"
    @State private var apertureTeleStr: String = "2.8"
    @State private var minDistanceStr: String = "0.38"

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Objektiv Details")) {
                    TextField("Name / Bezeichnung", text: $name)
                    Toggle("Zoom-Objektiv", isOn: $isZoom)

                    if isZoom {
                        HStack {
                            Text("Brennweite von")
                            Spacer()
                            TextField("Min mm", text: $minFocalStr)
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                            Text("bis")
                            TextField("Max mm", text: $maxFocalStr)
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                            Text("mm")
                        }
                    } else {
                        HStack {
                            Text("Brennweite")
                            Spacer()
                            TextField("Brennweite mm", text: $minFocalStr)
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                            Text("mm")
                        }
                    }

                    HStack {
                        Text("Offenblende (Weitwinkel)")
                        Spacer()
                        TextField("f/2.8", text: $apertureWideStr)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }

                    if isZoom {
                        HStack {
                            Text("Offenblende (Tele)")
                            Spacer()
                            TextField("f/2.8", text: $apertureTeleStr)
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    HStack {
                        Text("Naheinstellgrenze (Meter)")
                        Spacer()
                        TextField("0.38", text: $minDistanceStr)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle(lens == nil ? "Neues Objektiv" : "Objektiv bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let l = lens {
                    name = l.name
                    isZoom = l.isZoom
                    minFocalStr = "\(Int(round(l.minFocalLengthMM)))"
                    maxFocalStr = "\(Int(round(l.maxFocalLengthMM)))"
                    apertureWideStr = String(format: "%.1f", l.maxApertureWide)
                    apertureTeleStr = String(format: "%.1f", l.maxApertureTele ?? l.maxApertureWide)
                    minDistanceStr = String(format: "%.2f", l.minimumFocusDistanceM)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let minF = Double(minFocalStr.replacingOccurrences(of: ",", with: ".")) ?? 24.0
                        let maxF = isZoom ? (Double(maxFocalStr.replacingOccurrences(of: ",", with: ".")) ?? minF) : minF
                        let apW = Double(apertureWideStr.replacingOccurrences(of: ",", with: ".")) ?? 2.8
                        let apT = isZoom ? (Double(apertureTeleStr.replacingOccurrences(of: ",", with: ".")) ?? apW) : apW
                        let dist = Double(minDistanceStr.replacingOccurrences(of: ",", with: ".")) ?? 0.25

                        let savedLens = Lens(
                            id: lens?.id ?? UUID(),
                            name: name.isEmpty ? "Objektiv" : name,
                            isZoom: isZoom,
                            minFocalLengthMM: minF,
                            maxFocalLengthMM: maxF,
                            maxApertureWide: apW,
                            maxApertureTele: apT,
                            minimumFocusDistanceM: dist,
                            sensorFormat: .fullFrame,
                            createdAt: lens?.createdAt ?? Date(),
                            updatedAt: Date()
                        )
                        onSave(savedLens)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
