import CoreGraphics

nonisolated enum PunchPhase: Sendable {
    case idle
    case extending
    case retracting
}

nonisolated struct PunchPhaseStateMachine: Sendable {
    private(set) var phase: PunchPhase = .idle
    private var missedFrameCount: Int = 0

    mutating func update(areaGrowthRate: CGFloat?, handDetected: Bool) -> Bool {
        guard handDetected, let rate = areaGrowthRate else {
            missedFrameCount += 1
            if missedFrameCount >= 6 {
                phase = .idle
                missedFrameCount = 0
            }
            return false
        }

        missedFrameCount = 0

        switch phase {
        case .idle:
            if rate > 0.10 {
                phase = .extending
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
                return true
            }
            return false
        }
    }
}
