import Foundation

struct SeriesSummary: Equatable {
    let count: Int
    let mean: Double
    let stdDev: Double   // sample standard deviation (0 when count < 2)
    let min: Double
    let max: Double
}

enum Stats {
    static func summary(_ values: [Double]) -> SeriesSummary? {
        guard !values.isEmpty else { return nil }
        let n = Double(values.count)
        let mean = values.reduce(0, +) / n
        var sd = 0.0
        if values.count > 1 {
            let ss = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
            sd = (ss / (n - 1)).squareRoot()
        }
        return SeriesSummary(count: values.count, mean: mean, stdDev: sd,
                             min: values.min()!, max: values.max()!)
    }
}

enum TimeRange: String, CaseIterable, Identifiable {
    case week = "7D", month = "30D", quarter = "90D", all = "All"
    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .all: return nil
        }
    }

    func cutoff(from now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let d = days else { return nil }
        return calendar.date(byAdding: .day, value: -d, to: now)
    }
}

enum CSV {
    static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}
