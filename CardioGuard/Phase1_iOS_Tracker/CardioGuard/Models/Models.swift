import Foundation
import SwiftData

@Model
final class VitalReading {
    var id: UUID
    var date: Date
    var typeRaw: String
    var value: Double
    /// Diastolic pressure for blood-pressure readings; nil otherwise.
    var secondaryValue: Double?
    var note: String

    init(type: VitalType, value: Double, secondaryValue: Double? = nil,
         date: Date = .now, note: String = "") {
        self.id = UUID()
        self.date = date
        self.typeRaw = type.rawValue
        self.value = value
        self.secondaryValue = secondaryValue
        self.note = note
    }

    var type: VitalType { VitalType(rawValue: typeRaw) ?? .heartRate }

    var displayValue: String {
        if let s = secondaryValue {
            return "\(Int(value.rounded()))/\(Int(s.rounded())) \(type.unit)"
        }
        return "\(Int(value.rounded())) \(type.unit)"
    }
}

@Model
final class SymptomEntry {
    var id: UUID
    var date: Date
    var name: String
    /// 1 (mild) ... 5 (severe)
    var severity: Int
    var note: String

    init(name: String, severity: Int, date: Date = .now, note: String = "") {
        self.id = UUID()
        self.date = date
        self.name = name
        self.severity = severity
        self.note = note
    }
}

enum Condition: String, CaseIterable, Identifiable, Codable {
    case type1Diabetes = "Type 1 diabetes"
    case type2Diabetes = "Type 2 diabetes"
    case arrhythmia = "Arrhythmia"
    case postHeartAttack = "Prior heart attack"
    case heartFailure = "Heart failure"
    case hypertension = "High blood pressure"
    case other = "Other"

    var id: String { rawValue }
}

@Model
final class UserProfile {
    var name: String
    var conditions: [String]
    var medications: String
    var allergies: String
    var emergencyName: String
    var emergencyPhone: String
    var completedOnboarding: Bool

    init(name: String = "", conditions: [String] = [], medications: String = "",
         allergies: String = "", emergencyName: String = "", emergencyPhone: String = "",
         completedOnboarding: Bool = false) {
        self.name = name
        self.conditions = conditions
        self.medications = medications
        self.allergies = allergies
        self.emergencyName = emergencyName
        self.emergencyPhone = emergencyPhone
        self.completedOnboarding = completedOnboarding
    }
}
