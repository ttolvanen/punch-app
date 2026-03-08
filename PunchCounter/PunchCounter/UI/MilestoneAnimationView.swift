import SwiftUI

struct MilestoneAnimationView: View {
    let session: PunchSession

    @State private var isAnimating = false
    @State private var displayedMilestone: Int = 0

    var body: some View {
        ZStack {
            if isAnimating {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .stroke(lineWidth: 2)
                        .foregroundStyle(.white)
                        .scaleEffect(isAnimating ? 3.0 : 0.2)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.5)
                                .delay(Double(index) * 0.15),
                            value: isAnimating
                        )
                }
                .frame(width: 60, height: 60)

                Text("\(displayedMilestone)!")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(isAnimating ? 1.2 : 0.5)
                    .opacity(isAnimating ? 0 : 1)
                    .animation(.easeOut(duration: 1.5), value: isAnimating)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: session.lastMilestoneCount) { _, newValue in
            guard newValue > 0 else { return }
            displayedMilestone = newValue
            isAnimating = false
            withAnimation {
                isAnimating = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.6))
                isAnimating = false
            }
        }
    }
}
