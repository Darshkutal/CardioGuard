import SwiftUI
import SwiftData
import Charts

struct TrendView: View {
    let type: VitalType
    @Query private var readings: [VitalReading]
    @State private var range: TimeRange = .week

    init(type: VitalType) {
        self.type = type
        let raw = type.rawValue
        _readings = Query(filter: #Predicate<VitalReading> { $0.typeRaw == raw },
                          sort: \.date)
    }

    private var filtered: [VitalReading] {
        guard let cutoff = range.cutoff() else { return readings }
        return readings.filter { $0.date >= cutoff }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Range", selection: $range) {
                    ForEach(TimeRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if filtered.isEmpty {
                    ContentUnavailableView("No readings in this range",
                                           systemImage: "chart.xyaxis.line",
                                           description: Text("Log a reading to see your trend."))
                        .frame(height: 260)
                } else {
                    chart
                    statsGrid
                }
            }
            .padding()
        }
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var chart: some View {
        let summary = Stats.summary(filtered.map(\.value))
        return Chart {
            ForEach(filtered) { r in
                LineMark(x: .value("Date", r.date), y: .value("Value", r.value))
                    .foregroundStyle(by: .value("Measure", type.primaryLabel))
                PointMark(x: .value("Date", r.date), y: .value("Value", r.value))
                    .foregroundStyle(by: .value("Measure", type.primaryLabel))
                if let d = r.secondaryValue {
                    LineMark(x: .value("Date", r.date), y: .value("Value", d))
                        .foregroundStyle(by: .value("Measure", type.secondaryLabel))
                    PointMark(x: .value("Date", r.date), y: .value("Value", d))
                        .foregroundStyle(by: .value("Measure", type.secondaryLabel))
                }
            }
            if let m = summary?.mean {
                RuleMark(y: .value("Average", m))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("avg \(Int(m.rounded()))").font(.caption2).foregroundStyle(.secondary)
                    }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxisLabel(type.unit)
        .frame(height: 280)
    }

    private var statsGrid: some View {
        let s = Stats.summary(filtered.map(\.value))
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let s {
                statTile("Average", "\(Int(s.mean.rounded()))")
                statTile("Readings", "\(s.count)")
                statTile("Lowest", "\(Int(s.min.rounded()))")
                statTile("Highest", "\(Int(s.max.rounded()))")
            }
        }
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}
