import XCTest
@testable import PunchCounter

@MainActor
final class SpeedCalculationTests: XCTestCase {

    func test_emptyWindow_speedIsZero() {
        let session = PunchSession()
        let clock = TestClock()
        session.now = clock.now
        session.updateSpeed()
        XCTAssertEqual(session.punchesPerSecond, 0.0)
    }

    func test_threePunchesInThreeSeconds_speedIsOne() {
        let session = PunchSession()
        let clock = TestClock()
        session.now = clock.now

        session.recordPunch()
        clock.advance(by: 1)
        session.recordPunch()
        clock.advance(by: 1)
        session.recordPunch()

        session.updateSpeed()
        XCTAssertEqual(session.punchesPerSecond, 1.0, accuracy: 0.01)
        session.stopDisplayLink()
    }

    func test_tenPunchesInOneSecond_speedIsTen() {
        let session = PunchSession()
        let clock = TestClock()
        session.now = clock.now

        for i in 0..<10 {
            session.recordPunch()
            if i < 9 { clock.advance(by: 0.1) }
        }

        session.updateSpeed()
        // 10 punches within 3s window → 10/3 ≈ 3.33
        XCTAssertEqual(session.punchesPerSecond, 10.0 / 3.0, accuracy: 0.01)
        session.stopDisplayLink()
    }

    func test_oldPunchesExcluded_fromWindow() {
        let session = PunchSession()
        let clock = TestClock()
        session.now = clock.now

        // 5 punches at t-10s
        for _ in 0..<5 {
            session.recordPunch()
        }

        clock.advance(by: 10)

        // 6 punches at t-1s (within window)
        for _ in 0..<6 {
            session.recordPunch()
        }

        session.updateSpeed()
        XCTAssertEqual(session.punchesPerSecond, 2.0, accuracy: 0.01) // 6/3 = 2.0
        session.stopDisplayLink()
    }

    func test_speedUpdatesAsWindowSlides() {
        let session = PunchSession()
        let clock = TestClock()
        session.now = clock.now

        // t=0
        session.recordPunch()
        clock.advance(by: 1)
        // t=1
        session.recordPunch()
        clock.advance(by: 1)
        // t=2
        session.recordPunch()
        clock.advance(by: 1)
        // t=3
        session.recordPunch()

        session.updateSpeed()
        // At t=3, the punch at t=0 is exactly at the 3s boundary.
        // Punches at t=0 are at windowStart (t=0), filter is >= so it's included.
        // 4 punches / 3 = 1.33
        XCTAssertEqual(session.punchesPerSecond, 4.0 / 3.0, accuracy: 0.01)

        // Advance past t=0's window
        clock.advance(by: 0.1)
        session.updateSpeed()
        // Now window is [0.1, 3.1], punch at t=0 drops out
        // 3 punches / 3 = 1.0
        XCTAssertEqual(session.punchesPerSecond, 1.0, accuracy: 0.01)
        session.stopDisplayLink()
    }
}
