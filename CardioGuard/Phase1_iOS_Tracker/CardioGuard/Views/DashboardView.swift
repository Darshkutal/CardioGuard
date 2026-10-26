import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \VitalReading.date, order: .reverse) private var readings: [VitalReading]
    @Query private var profiles: [UserProfile]
    @State private var showVitalLog = false
    @State private var showSymptomLog = false

    private var greeting: String {
        let name = profiles.first?.name ?? ""
        return name.isEmpty ? "Today" : "Hi, \(name)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        bigButton("Log Vitals", systemImage: "plus.circle.fill", tint: .accentColor) {
                            showVitalLog = true
                        }
                        bigButton("Log Symptom", systemImage: "exclamationmark.bubble.fill", tint: .orange) {
                            showSymptomLog = true
                        }
                    }

                    ForEach(VitalType.allCases) { type in
                        NavigationLink(value: type) {
                            VitalCard(type: type,
                                      readings: readings.filter { $0.typeRaw == type.rawValue })
                        }
                        .buttonStyle(.plain)
                    }

                    Text("CardioGuard tracks your readings but does not diagnose or replace medical care. In an emergency, call 911.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle(greeting)
            .navigationDestination(for: VitalType.self) { TrendView(type: $0) }
            .sheet(isPresented: $showVitalLog) { LogEntryView() }
            .sheet(isPresented: $showSymptomLog) { SymptomLogView() }
        }
    }

    private func bigButton(_ title: String, systemImage: String, tint: Color,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}

struct VitalCard: View {
    let type: VitalType
    /// Newest first.
    let readings: [VitalReading]

    private var recent: [VitalReading] {
        guard let cutoff = TimeRange.week.cutoff() else { return readings }
        return readings.filter { $0.date >= cutoff }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(type.title, systemImage: type.symbol)
                    .font(.headline)
                    .foregroundStyle(type.tint)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }

            if let latest = readings.first {
                Text(latest.displayValue)
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text(latest.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let s = Stats.summary(recent.map(\.value)) {
                    Text("7-day average: \(Int(s.mean.rounded())) (\(recent.count) readings)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if recent.count > 1 {
                    Chart(recent.reversed()) { r in
                        LineMark(x: .value("Date", r.date), y: .value("Value", r.value))
                            .foregroundStyle(type.tint)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 44)
                }
            } else {
                Text("No readings yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
