import SwiftUI

struct StatsOverlayView: View {
    let session: PunchSession

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            VStack(spacing: 12) {
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.fill")
                                .font(.title2)
                            Text("\(session.punchCount)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                                .animation(.default, value: session.punchCount)
                        }
                        Text("PUNCHES")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", session.punchesPerSecond) + " /s")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                            .animation(.default, value: session.punchesPerSecond)
                        Text("SPEED")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Session: \(formattedDuration)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    session.reset()
                } label: {
                    Text("RESET")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var formattedDuration: String {
        let total = Int(session.sessionDuration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
