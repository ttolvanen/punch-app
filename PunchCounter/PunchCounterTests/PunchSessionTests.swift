import XCTest
@testable import PunchCounter

@MainActor
final class PunchSessionTests: XCTestCase {

    func test_initialState_isInactive_zeroStats() {
        let session = PunchSession()
        XCTAssertEqual(session.punchCount, 0)
        XCTAssertEqual(session.punchesPerSecond, 0.0)
        XCTAssertEqual(session.sessionDuration, 0.0)
        XCTAssertFalse(session.isActive)
    }

    func test_recordPunch_firstPunch_activatesSession() {
        let session = PunchSession()
        let clock = TestClock()
        session.now = clock.now
        session.recordPunch()
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(session.punchCount, 1)
        session.stopDisplayLink()
    }

    func test_recordPunch_multipleCallsIncrementCount() {
        let session = PunchSession()
        let clock = TestClock()
        session.now = clock.now
        for _ in 0..<5 {
            session.recordPunch()
        }
        XCTAssertEqual(session.punchCount, 5)
        session.stopDisplayLink()
    }

    func test_reset_clearsAllState() {
        let session = PunchSession()
        let clock = TestClock()
        session.now = clock.now
        session.recordPunch()
        session.recordPunch()
        session.recordPunch()
        session.reset()
        XCTAssertEqual(session.punchCount, 0)
        XCTAssertEqual(session.punchesPerSecond, 0.0)
        XCTAssertEqual(session.sessionDuration, 0.0)
        XCTAssertFalse(session.isActive)
    }

    func test_recentPunches_cappedAtTwenty() {
        let session = PunchSession()
        let clock = TestClock()
        session.now = clock.now
        for _ in 0..<25 {
            session.recordPunch()
        }
        XCTAssertLessThanOrEqual(session.recentPunches.count, 20)
        session.stopDisplayLink()
    }

    func test_punchesPerSecond_onlyCountsRecentWindow() {
        let session = PunchSession()
        let clock = TestClock()
        session.now = clock.now

        // Add 5 "old" punches at t=-10s
        clock.current = Date(timeIntervalSinceReferenceDate: 0)
        for _ in 0..<5 {
            session.recordPunch()
        }

        // Advance time so those punches are old
        clock.advance(by: 10)

        // Add 3 recent punches
        for _ in 0..<3 {
            session.recordPunch()
        }

        session.updateSpeed()
        XCTAssertEqual(session.punchesPerSecond, 1.0, accuracy: 0.01)
        session.stopDisplayLink()
    }
}
