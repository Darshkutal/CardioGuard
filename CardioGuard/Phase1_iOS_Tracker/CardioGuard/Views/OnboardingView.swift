import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var selected: Set<Condition> = []
    @State private var medications = ""
    @State private var allergies = ""
    @State private var emergencyName = ""
    @State private var emergencyPhone = ""
    @State private var acknowledged = false

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && acknowledged
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("CardioGuard helps you track your heart and glucose readings and see how they change over time. Your data stays on this device.")
                        .font(.body)
                }

                Section("About you") {
                    TextField("First name", text: $name)
                        .textContentType(.givenName)
                }

                Section("Conditions you manage") {
                    ForEach(Condition.allCases) { c in
                        Toggle(c.rawValue, isOn: Binding(
                            get: { selected.contains(c) },
                            set: { on in
                                if on { selected.insert(c) } else { selected.remove(c) }
                            }))
                    }
                }

                Section("Medications & allergies") {
                    TextField("Medications (optional)", text: $medications, axis: .vertical)
                    TextField("Allergies (optional)", text: $allergies, axis: .vertical)
                }

                Section {
                    TextField("Contact name", text: $emergencyName)
                        .textContentType(.name)
                    TextField("Contact phone", text: $emergencyPhone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                } header: {
                    Text("Emergency contact")
                } footer: {
                    Text("Saved for later. Automatic alerts to this contact are not active yet.")
                }

                Section {
                    Toggle(isOn: $acknowledged) {
                        Text("I understand CardioGuard is a tracking tool, not a medical device. It does not diagnose conditions and does not replace medical care. In an emergency, call 911.")
                            .font(.callout)
                    }
                }

                Section {
                    Button(action: save) {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canContinue)
                }
            }
            .navigationTitle("Welcome")
        }
    }

    private func save() {
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            conditions: selected.map(\.rawValue).sorted(),
            medications: medications,
            allergies: allergies,
            emergencyName: emergencyName,
            emergencyPhone: emergencyPhone,
            completedOnboarding: true)
        context.insert(profile)
        try? context.save()
    }
}
