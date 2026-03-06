import CoreGraphics

nonisolated enum PunchPhase: Sendable {
    case idle
    case extending
    case retracting
}

nonisolated struct PunchPhaseStateMachine: Sendable {
    private(set) var phase: PunchPhase = .idle
    private var extendingFrameCount: Int = 0
    private var missedFrameCount: Int = 0

    mutating func update(areaGrowthRate: CGFloat?, handDetected: Bool) -> Bool {
        guard handDetected, let rate = areaGrowthRate else {
            missedFrameCount += 1
            if missedFrameCount >= 10 {
                phase = .idle
                extendingFrameCount = 0
                missedFrameCount = 0
            }
            return false
        }

        missedFrameCount = 0

        switch phase {
        case .idle:
            if rate > 0.15 {
                extendingFrameCount += 1
                if extendingFrameCount >= 2 {
                    phase = .extending
                    extendingFrameCount = 0
                }
            } else {
                extendingFrameCount = 0
            }
            return false

        case .extending:
            if rate < -0.05 {
                phase = .retracting
            }
            return false

        case .retracting:
            if rate > -0.02 {
                phase = .idle
                extendingFrameCount = 0
                return true
            }
            return false
        }
    }
}
