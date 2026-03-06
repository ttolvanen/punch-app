import XCTest
@testable import PunchCounter

final class PunchPhaseStateMachineTests: XCTestCase {

    func test_idle_toExtending_onSingleGrowthFrame() {
        var sm = PunchPhaseStateMachine()
        // Single frame with rate 0.20 → phase transitions to .extending
        let _ = sm.update(areaGrowthRate: 0.20, handDetected: true)
        XCTAssertEqual(sm.phase, .extending)
    }

    func test_extending_toRetracting_onNegativeGrowth() {
        var sm = PunchPhaseStateMachine()
        // Drive to .extending
        let _ = sm.update(areaGrowthRate: 0.20, handDetected: true)
        XCTAssertEqual(sm.phase, .extending)
        // Negative growth → .retracting
        let _ = sm.update(areaGrowthRate: -0.10, handDetected: true)
        XCTAssertEqual(sm.phase, .retracting)
    }

    func test_retracting_toIdle_emitsPunch_onStabilisation() {
        var sm = PunchPhaseStateMachine()
        // Full cycle
        let _ = sm.update(areaGrowthRate: 0.20, handDetected: true)
        let _ = sm.update(areaGrowthRate: -0.10, handDetected: true)
        // Stabilise
        let result = sm.update(areaGrowthRate: 0.0, handDetected: true)
        XCTAssertTrue(result)
        XCTAssertEqual(sm.phase, .idle)
    }

    func test_missingHandFrames_resetsToIdle() {
        var sm = PunchPhaseStateMachine()
        // Drive to .extending
        let _ = sm.update(areaGrowthRate: 0.20, handDetected: true)
        XCTAssertEqual(sm.phase, .extending)
        // 6 frames with no hand (reduced from 10)
        for _ in 0..<6 {
            let _ = sm.update(areaGrowthRate: nil, handDetected: false)
        }
        XCTAssertEqual(sm.phase, .idle)
    }

    func test_noFalsePositive_slowGrowth() {
        var sm = PunchPhaseStateMachine()
        // rate 0.05 (below threshold of 0.10) never transitions out of .idle
        for _ in 0..<20 {
            let result = sm.update(areaGrowthRate: 0.05, handDetected: true)
            XCTAssertFalse(result)
            XCTAssertEqual(sm.phase, .idle)
        }
    }

    func test_fullPunchCycle_returnsTrue_exactlyOnce() {
        var sm = PunchPhaseStateMachine()
        var punchCount = 0

        // idle → extending
        punchCount += sm.update(areaGrowthRate: 0.20, handDetected: true) ? 1 : 0
        // extending → retracting
        punchCount += sm.update(areaGrowthRate: -0.10, handDetected: true) ? 1 : 0
        // retracting → idle (punch!)
        punchCount += sm.update(areaGrowthRate: 0.0, handDetected: true) ? 1 : 0

        XCTAssertEqual(punchCount, 1)
    }

    func test_fiveMissedFrames_doesNotReset() {
        var sm = PunchPhaseStateMachine()
        // Drive to .extending
        let _ = sm.update(areaGrowthRate: 0.20, handDetected: true)
        XCTAssertEqual(sm.phase, .extending)
        // 5 frames (below threshold of 6) should NOT reset
        for _ in 0..<5 {
            let _ = sm.update(areaGrowthRate: nil, handDetected: false)
        }
        XCTAssertEqual(sm.phase, .extending)
    }
}
