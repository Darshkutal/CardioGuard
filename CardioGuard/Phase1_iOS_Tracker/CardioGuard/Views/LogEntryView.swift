import SwiftUI
import SwiftData

struct LogEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var type: VitalType = .heartRate
    @State private var primary = ""
    @State private var secondary = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Measurement") {
                    Picker("Type", selection: $type) {
                        ForEach(VitalType.allCases) { Text($0.title).tag($0) }
                    }
                    .onChange(of: type) { _, _ in primary = ""; secondary = ""; error = nil }
                }

                Section {
                    HStack {
                        TextField(type.primaryLabel, text: $primary)
                            .keyboardType(.numberPad)
                            .font(.title2)
                        Text(type.hasSecondary ? "" : type.unit).foregroundStyle(.secondary)
                    }
                    if type.hasSecondary {
                        HStack {
                            TextField(type.secondaryLabel, text: $secondary)
                                .keyboardType(.numberPad)
                                .font(.title2)
                            Text(type.unit).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Value")
                } footer: {
                    if let error { Text(error).foregroundStyle(.red) }
                }

                Section {
                    DatePicker("When", selection: $date, in: ...Date.now)
                    TextField("Note (optional)", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Log Vitals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    private func save() {
        guard let v = Double(primary), type.plausibleRange.contains(v) else {
            error = "Enter a \(type.primaryLabel.lowercased()) value between \(Int(type.plausibleRange.lowerBound)) and \(Int(type.plausibleRange.upperBound))."
            return
        }
        var second: Double?
        if type.hasSecondary {
            guard let d = Double(secondary), type.plausibleSecondaryRange.contains(d), d < v else {
                error = "Enter a diastolic value between \(Int(type.plausibleSecondaryRange.lowerBound)) and \(Int(type.plausibleSecondaryRange.upperBound)), lower than systolic."
                return
            }
            second = d
        }
        context.insert(VitalReading(type: type, value: v, secondaryValue: second,
                                    date: date, note: note))
        try? context.save()
        dismiss()
    }
}

struct SymptomLogView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let common = ["Chest pain", "Shortness of breath", "Dizziness", "Palpitations",
                          "Fatigue", "Swelling", "Nausea", "Shakiness", "Excessive thirst", "Headache"]

    @State private var selected = "Chest pain"
    @State private var custom = ""
    @State private var severity = 2
    @State private var date = Date()
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Symptom", selection: $selected) {
                        ForEach(common, id: \.self) { Text($0).tag($0) }
                        Text("Other").tag("Other")
                    }
                    if selected == "Other" {
                        TextField("Describe symptom", text: $custom)
                    }
                } footer: {
                    Text("If you have severe chest pain, trouble breathing, or feel like you may faint, call 911.")
                }

                Section("Severity") {
                    Picker("Severity", selection: $severity) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text("Mild").font(.caption)
                        Spacer()
                        Text("Severe").font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Section {
                    DatePicker("When", selection: $date, in: ...Date.now)
                    TextField("Note (optional)", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Log Symptom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(selected == "Other" && custom.isEmpty)
                }
            }
        }
    }

    private func save() {
        let name = selected == "Other" ? custom : selected
        context.insert(SymptomEntry(name: name, severity: severity, date: date, note: note))
        try? context.save()
        dismiss()
    }
}
