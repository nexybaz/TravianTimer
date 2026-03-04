import SwiftUI

// MARK: - Attack Countdown Row

struct AttackCountdownRow: View {

    let attack: PlannedAttack
    let isPlanner: Bool
    let now: Date
    let onConfirm: (Bool) -> Void
    let onSent: (Bool) -> Void

    private var isLate: Bool { attack.departureAt < now }

    private var remaining: TimeInterval {
        attack.departureAt.timeIntervalSince(now)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Farbiger Akzentstreifen
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4)

                VStack(spacing: 8) {
                    // Obere Zeile: Spieler + Countdown
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(attack.playerName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)

                            Text("\(attack.villageName) (\(attack.villageX)|\(attack.villageY))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            if isLate {
                                if attack.sent {
                                    Label("Gesendet", systemImage: "paperplane.fill")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("Abgelaufen")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.red)
                                }
                            } else {
                                Text(formatDuration(remaining))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                                    .foregroundStyle(remaining < 300 ? .red : .primary)
                            }

                            Text(attack.departureAt.formatted(date: .omitted, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    // Untere Zeile: Typ + Ziel + Badges
                    HStack {
                        HStack(spacing: 8) {
                            // Typ-Badge
                            HStack(spacing: 3) {
                                Image(systemName: attack.attackType.icon)
                                    .font(.caption2)
                                Text(attack.attackType.shortLabel)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(attack.attackType.color)
                            .clipShape(Capsule())

                            Text(targetLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Text("MS \(Int(attack.troopSpeed))")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        Spacer()

                        // Status Badges
                        HStack(spacing: 6) {
                            if attack.confirmed {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            if attack.sent {
                                Image(systemName: "paperplane.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }

                    // Bestaetigungs-Buttons
                    if !isLate && !attack.confirmed {
                        confirmationButtons
                    } else if isLate && attack.confirmed && !attack.sent {
                        sentButtons
                    }
                }
                .padding(12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(rowBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Confirmation Buttons

    private var confirmationButtons: some View {
        HStack(spacing: 10) {
            Text("Teilnahme?")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onConfirm(true)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("Ja")
                }
                .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Button {
                onConfirm(false)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                    Text("Nein")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    private var sentButtons: some View {
        HStack(spacing: 10) {
            Text("Gesendet?")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onSent(true)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "paperplane")
                    Text("Ja")
                }
                .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            Button {
                onSent(false)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                    Text("Nein")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    // MARK: - Helpers

    private var targetLabel: String {
        var parts: [String] = []
        if let p = attack.targetPlayer { parts.append(p) }
        if let v = attack.targetVillage { parts.append(v) }
        parts.append("(\(attack.targetX)|\(attack.targetY))")
        return parts.joined(separator: " ")
    }

    private var accentColor: Color {
        if attack.sent { return .blue }
        if isLate { return .red }
        if attack.confirmed { return .green }
        return attack.attackType.color
    }

    private var rowBackground: Color {
        if attack.sent { return .blue.opacity(0.05) }
        if isLate { return .red.opacity(0.04) }
        return Color(.secondarySystemGroupedBackground)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(abs(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
