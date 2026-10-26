import Foundation

enum Exporter {
    /// Builds a CSV of all vitals and symptoms and writes it to a temp file for sharing with a doctor.
    static func makeCSV(readings: [VitalReading], symptoms: [SymptomEntry]) -> URL? {
        let iso = ISO8601DateFormatter()
        var lines = ["date,category,measure,value,value2,unit,note"]

        for r in readings.sorted(by: { $0.date < $1.date }) {
            let second = r.secondaryValue.map { String(format: "%.0f", $0) } ?? ""
            lines.append([
                iso.string(from: r.date), "vital", r.type.title,
                String(format: "%.0f", r.value), second, r.type.unit, CSV.escape(r.note)
            ].joined(separator: ","))
        }
        for s in symptoms.sorted(by: { $0.date < $1.date }) {
            lines.append([
                iso.string(from: s.date), "symptom", CSV.escape(s.name),
                String(s.severity), "", "severity 1-5", CSV.escape(s.note)
            ].joined(separator: ","))
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CardioGuard-Export.csv")
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
