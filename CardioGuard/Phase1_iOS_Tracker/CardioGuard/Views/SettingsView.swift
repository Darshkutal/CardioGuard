import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var confirmErase = false

    var body: some View {
        NavigationStack {
            Form {
                if let profile = profiles.first {
                    ProfileForm(profile: profile)
                }

                #if DEBUG
                Section("Developer") {
                    Button("Load 30 days of demo data", action: loadDemoData)
                }
                #endif

                Section {
                    Button("Erase all logged data", role: .destructive) { confirmErase = true }
                } footer: {
                    Text("All data is stored only on this device. CardioGuard is a tracking tool and does not diagnose or replace medical care. In an emergency, call 911.")
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog("Erase all vitals and symptoms?", isPresented: $confirmErase,
                                titleVisibility: .visible) {
                Button("Erase", role: .destructive, action: eraseAll)
            }
        }
    }

    private func eraseAll() {
        try? context.delete(model: VitalReading.self)
        try? context.delete(model: SymptomEntry.self)
        try? context.save()
    }

    #if DEBUG
    private func loadDemoData() {
        let cal = Calendar.current
        for day in 0..<30 {
            guard let d = cal.date(byAdding: .day, value: -day, to: .now) else { continue }
            let hr = 70 + Double.random(in: -8...8)
            context.insert(VitalReading(type: .heartRate, value: hr.rounded(), date: d))
            let sys = 122 + Double.random(in: -10...10)
            context.insert(VitalReading(type: .bloodPressure, value: sys.rounded(),
                                        secondaryValue: (sys - 42 + Double.random(in: -4...4)).rounded(), date: d))
            context.insert(VitalReading(type: .glucose, value: (110 + Double.random(in: -25...40)).rounded(), date: d))
            context.insert(VitalReading(type: .oxygen, value: (97 + Double.random(in: -2...2)).rounded(), date: d))
        }
        try? context.save()
    }
    #endif
}

private struct ProfileForm: View {
    @Bindable var profile: UserProfile

    var body: some View {
        Section("About you") {
            TextField("First name", text: $profile.name)
            if !profile.conditions.isEmpty {
                LabeledContent("Conditions", value: profile.conditions.joined(separator: ", "))
            }
        }
        Section("Medications & allergies") {
            TextField("Medications", text: $profile.medications, axis: .vertical)
            TextField("Allergies", text: $profile.allergies, axis: .vertical)
        }
        Section {
            TextField("Contact name", text: $profile.emergencyName)
            TextField("Contact phone", text: $profile.emergencyPhone)
                .keyboardType(.phonePad)
        } header: {
            Text("Emergency contact")
        } footer: {
            Text("Automatic alerts to this contact are not active yet.")
        }
    }
}
