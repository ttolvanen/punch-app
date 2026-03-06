import XCTest
@testable import PunchCounter

final class PunchPhaseStateMachineTests: XCTestCase {

    func test_idle_toExtending_requiresTwoConsecutiveGrowthFrames() {
        var sm = PunchPhaseStateMachine()
        // Single frame with rate 0.20 → phase still .idle
        let _ = sm.update(areaGrowthRate: 0.20, handDetected: true)
        XCTAssertEqual(sm.phase, .idle)
        // Second frame with rate 0.20 → phase == .extending
        let _ = sm.update(areaGrowthRate: 0.20, handDetected: true)
        XCTAssertEqual(sm.phase, .extending)
    }

    func test_extending_toRetracting_onNegativeGrowth() {
        var sm = PunchPhaseStateMachine()
        // Drive to .extending
        let _ = sm.update(areaGrowthRate: 0.20, handDetected: true)
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
        let _ = sm.update(areaGrowthRate: 0.20, handDetected: true)
        XCTAssertEqual(sm.phase, .extending)
        // 10 frames with no hand
        for _ in 0..<10 {
            let _ = sm.update(areaGrowthRate: nil, handDetected: false)
        }
        XCTAssertEqual(sm.phase, .idle)
    }

    func test_noFalsePositive_slowGrowth() {
        var sm = PunchPhaseStateMachine()
        // rate 0.05 (below threshold) never transitions out of .idle
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
        punchCount += sm.update(areaGrowthRate: 0.20, handDetected: true) ? 1 : 0
        // extending → retracting
        punchCount += sm.update(areaGrowthRate: -0.10, handDetected: true) ? 1 : 0
        // retracting → idle (punch!)
        punchCount += sm.update(areaGrowthRate: 0.0, handDetected: true) ? 1 : 0

        XCTAssertEqual(punchCount, 1)
    }

    func test_consecutiveCountResets_onNonExtendingFrame() {
        var sm = PunchPhaseStateMachine()
        // rate 0.20 (frame 1)
        let _ = sm.update(areaGrowthRate: 0.20, handDetected: true)
        // rate 0.02 (frame 2 — not extending, resets count)
        let _ = sm.update(areaGrowthRate: 0.02, handDetected: true)
        // rate 0.20 (frame 3 — only 1 consecutive, not 2)
        let _ = sm.update(areaGrowthRate: 0.20, handDetected: true)
        XCTAssertEqual(sm.phase, .idle)
    }
}
