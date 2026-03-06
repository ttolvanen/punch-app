import Foundation

final class TestClock: @unchecked Sendable {
    var current: Date = Date(timeIntervalSinceReferenceDate: 0)
    func advance(by seconds: TimeInterval) { current += seconds }
    var now: @Sendable () -> Date { { self.current } }
}
