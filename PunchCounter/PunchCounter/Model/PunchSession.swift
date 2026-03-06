import Foundation
import UIKit
import Observation

@Observable
@MainActor
final class PunchSession {
    private(set) var punchCount: Int = 0
    private(set) var punchesPerSecond: Double = 0.0
    private(set) var sessionDuration: TimeInterval = 0.0
    private(set) var isActive: Bool = false

    var recentPunches: [Date] = []
    private var sessionStart: Date?
    private var timer: Timer?

    var now: @Sendable () -> Date = { Date() }

    func recordPunch() {
        let timestamp = now()
        punchCount += 1
        recentPunches.append(timestamp)
        if recentPunches.count > 20 {
            recentPunches.removeFirst(recentPunches.count - 20)
        }
        if !isActive {
            isActive = true
            sessionStart = timestamp
            startDisplayLink()
        }
        updateSpeed()

        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }

    func reset() {
        punchCount = 0
        punchesPerSecond = 0.0
        sessionDuration = 0.0
        isActive = false
        recentPunches.removeAll()
        sessionStart = nil
        stopDisplayLink()
    }

    func startDisplayLink() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.timerFired()
            }
        }
    }

    func stopDisplayLink() {
        timer?.invalidate()
        timer = nil
    }

    private func timerFired() {
        guard let start = sessionStart else { return }
        let currentTime = now()
        sessionDuration = currentTime.timeIntervalSince(start)
        updateSpeed()
    }

    func updateSpeed() {
        let currentTime = now()
        let windowStart = currentTime.addingTimeInterval(-3.0)
        let recentCount = recentPunches.filter { $0 >= windowStart }.count
        punchesPerSecond = Double(recentCount) / 3.0
    }
}
