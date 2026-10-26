import Foundation

// CardioGuard demo scenario for the Congressional App Challenge video.
//
// A SIMULATED patient: 18 stable days, then a 3-day drift in heart rate, blood pressure
// and glucose. The last two readings are meant to be typed in ON CAMERA. Run through the
// Phase 3 scoring engine, the first typed reading is flagged "note" and the second "urgent";
// the stable days produce no false alarms. That check used the Phase 3 Python engine; your
// app's own alert logic may judge these numbers differently, so rehearse before recording.
//
// Say or show "simulated demo data" in the video. Never present these as a real patient.

struct DemoReadingRow {
    /// Hours before "now" this reading was taken.
    let hoursAgo: Double
    let heartRate: Int
    let systolic: Int
    let diastolic: Int
    let glucose: Int
    let oxygen: Int
}

enum DemoScenario {

    static let heartRate: [Int] = [
        66, 69, 62, 72, 70, 67, 67, 69, 67, 67, 70, 70, 68, 68,
        68, 66, 67, 70, 68, 64, 67, 70, 67, 68, 70, 73, 66, 72,
        64, 69, 64, 72, 71, 71, 65, 70, 70, 74, 79, 83, 99, 100
    ]

    static let systolic: [Int] = [
        119, 128, 124, 125, 131, 119, 132, 135, 128, 125, 119, 126, 120, 122,
        121, 123, 127, 120, 118, 118, 118, 116, 118, 127, 120, 123, 117, 123,
        115, 119, 131, 120, 126, 124, 121, 119, 133, 130, 140, 135, 156, 162
    ]

    static let diastolic: [Int] = [
        77, 83, 80, 82, 86, 77, 90, 88, 81, 79, 76, 87, 76, 80,
        76, 78, 80, 77, 77, 74, 78, 73, 75, 85, 78, 82, 72, 75,
        72, 75, 88, 80, 81, 83, 80, 77, 90, 83, 91, 87, 98, 104
    ]

    static let glucose: [Int] = [
        114, 127, 109, 102, 94, 102, 119, 99, 108, 131, 120, 128, 103, 90,
        126, 99, 113, 114, 103, 126, 126, 117, 112, 114, 102, 110, 111, 104,
        120, 99, 108, 92, 116, 119, 118, 138, 134, 126, 166, 146, 207, 215
    ]

    static let oxygen: [Int] = [
        96, 98, 97, 97, 96, 98, 96, 96, 98, 97, 97, 99, 98, 98,
        98, 96, 98, 98, 98, 97, 94, 97, 97, 97, 98, 97, 97, 96,
        96, 97, 97, 97, 97, 97, 97, 97, 97, 98, 97, 98, 98, 97
    ]

    /// All 42 readings, oldest first, one every 12 hours, newest 1 hour ago.
    static var allRows: [DemoReadingRow] {
        var rows: [DemoReadingRow] = []
        let n: Int = heartRate.count
        for i in 0..<n {
            let hours: Double = Double(n - 1 - i) * 12.0 + 1.0
            let row = DemoReadingRow(hoursAgo: hours,
                                     heartRate: heartRate[i],
                                     systolic: systolic[i],
                                     diastolic: diastolic[i],
                                     glucose: glucose[i],
                                     oxygen: oxygen[i])
            rows.append(row)
        }
        return rows
    }

    /// Load these into the app BEFORE recording (40 readings, about 20 days).
    static var preloaded: [DemoReadingRow] {
        return Array(allRows.dropLast(2))
    }

    /// Type these two in on camera, in order. Expect "note" then "urgent".
    /// Reading 1: heart rate 99, BP 156/98, glucose 207.
    /// Reading 2: heart rate 100, BP 162/104, glucose 215.
    static var typeOnCamera: [DemoReadingRow] {
        return Array(allRows.suffix(2))
    }

    static func date(for row: DemoReadingRow, now: Date = Date()) -> Date {
        return now.addingTimeInterval(-row.hoursAgo * 3600.0)
    }
}

// MARK: - Loading into YOUR app
//
// The loader depends on your SwiftData model initializers, which I have not seen.
// Paste your Models.swift to me and I will fill this in exactly. Until then, edit the
// body of `insertDemoData` to call YOUR initializers (property names below come from your
// CSVExporter screenshot: timestamp, heartRateBPM, systolic, diastolic, glucoseMGDL, notes).
//
// import SwiftData
//
// func insertDemoData(into context: ModelContext) {
//     for row in DemoScenario.preloaded {
//         let when: Date = DemoScenario.date(for: row)
//         // context.insert(<YourVitalReading>(timestamp: when, heartRateBPM: Double(row.heartRate), ...))
//     }
//     try? context.save()
// }
