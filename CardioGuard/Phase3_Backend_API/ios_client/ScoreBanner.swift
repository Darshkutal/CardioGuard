import SwiftUI

/// Plain-language result card. Drop it under a saved reading or at the top of the dashboard.
struct ScoreBanner: View {
    let result: ScoreResult

    private var tint: Color {
        switch result.tier {
        case "urgent": return .red
        case "note": return .orange
        default: return .green
        }
    }

    private var title: String {
        switch result.tier {
        case "urgent": return "Very different from your normal"
        case "note": return "Different from your normal"
        default: return "Looks like your normal"
        }
    }

    private var symbol: String {
        switch result.tier {
        case "urgent": return "exclamationmark.triangle.fill"
        case "note": return "info.circle.fill"
        default: return "checkmark.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(tint)

            ForEach(result.reasons, id: \.self) { reason in
                Text(reason).font(.subheadline)
            }

            Text(result.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if result.confidence == "low" {
                Text("Still learning your normal. Keep logging for better accuracy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(result.disclaimer)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
