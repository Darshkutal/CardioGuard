import Foundation
import SwiftUI

enum VitalType: String, CaseIterable, Identifiable, Codable, Hashable {
    case heartRate, bloodPressure, glucose, oxygen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heartRate: return "Heart Rate"
        case .bloodPressure: return "Blood Pressure"
        case .glucose: return "Blood Glucose"
        case .oxygen: return "Oxygen Level"
        }
    }

    var unit: String {
        switch self {
        case .heartRate: return "bpm"
        case .bloodPressure: return "mmHg"
        case .glucose: return "mg/dL"
        case .oxygen: return "%"
        }
    }

    var symbol: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .bloodPressure: return "waveform.path.ecg"
        case .glucose: return "drop.fill"
        case .oxygen: return "lungs.fill"
        }
    }

    var tint: Color {
        switch self {
        case .heartRate: return .red
        case .bloodPressure: return .purple
        case .glucose: return .blue
        case .oxygen: return .teal
        }
    }

    var hasSecondary: Bool { self == .bloodPressure }

    var primaryLabel: String { self == .bloodPressure ? "Systolic" : title }
    var secondaryLabel: String { "Diastolic" }

    /// Broad bounds used only to catch typos on entry (e.g. 5000 bpm). Not medical thresholds.
    var plausibleRange: ClosedRange<Double> {
        switch self {
        case .heartRate: return 20...250
        case .bloodPressure: return 50...260
        case .glucose: return 20...800
        case .oxygen: return 50...100
        }
    }

    var plausibleSecondaryRange: ClosedRange<Double> { 30...180 }
}
