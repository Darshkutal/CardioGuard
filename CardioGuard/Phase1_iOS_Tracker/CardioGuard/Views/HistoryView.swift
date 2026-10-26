import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VitalReading.date, order: .reverse) private var readings: [VitalReading]
    @Query(sort: \SymptomEntry.date, order: .reverse) private var symptoms: [SymptomEntry]
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Show", selection: $tab) {
                    Text("Vitals").tag(0)
                    Text("Symptoms").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                List {
                    if tab == 0 {
                        ForEach(readings) { r in
                            HStack {
                                Image(systemName: r.type.symbol).foregroundStyle(r.type.tint)
                                VStack(alignment: .leading) {
                                    Text(r.type.title).font(.headline)
                                    Text(r.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                    if !r.note.isEmpty { Text(r.note).font(.caption) }
                                }
                                Spacer()
                                Text(r.displayValue).font(.body.monospacedDigit())
                            }
                        }
                        .onDelete { idx in
                            idx.map { readings[$0] }.forEach(context.delete)
                            try? context.save()
                        }
                    } else {
                        ForEach(symptoms) { s in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(s.name).font(.headline)
                                    Text(s.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                    if !s.note.isEmpty { Text(s.note).font(.caption) }
                                }
                                Spacer()
                                Text("Severity \(s.severity)/5")
                            }
                        }
                        .onDelete { idx in
                            idx.map { symptoms[$0] }.forEach(context.delete)
                            try? context.save()
                        }
                    }
                }
                .overlay {
                    if (tab == 0 && readings.isEmpty) || (tab == 1 && symptoms.isEmpty) {
                        ContentUnavailableView("Nothing logged yet", systemImage: "tray")
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                if let url = Exporter.makeCSV(readings: readings, symptoms: symptoms) {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: url) { Label("Export for doctor", systemImage: "square.and.arrow.up") }
                    }
                }
            }
        }
    }
}
