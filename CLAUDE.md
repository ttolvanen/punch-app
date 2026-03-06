# Punch App – Claude Code Implementation Prompt

Create a complete iOS 18+ Xcode project called **PunchCounter** that uses the front camera and Apple Vision framework to detect and count chain punches in real time.

## Requirements

- **Swift 6**, strict concurrency enabled
- **SwiftUI + @Observable** (no ObservableObject)
- **No third-party dependencies**
- Targets **iOS 18.0+**
- Must build without warnings

---

## Project Structure

```
PunchCounter/
├── PunchCounterApp.swift
├── Camera/
│   └── CameraSession.swift
├── Vision/
│   └── HandPoseDetector.swift
├── Model/
│   └── PunchSession.swift
├── UI/
│   ├── ContentView.swift
│   ├── CameraPreviewView.swift
│   └── StatsOverlayView.swift
└── Info.plist   ← NSCameraUsageDescription required
```

---

## File Specifications

### PunchCounterApp.swift
```swift
@main
struct PunchCounterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

---

### Camera/CameraSession.swift

- `final class CameraSession: NSObject, @unchecked Sendable`
- Sets up `AVCaptureSession` with `.front` camera
- Output: `AVCaptureVideoDataOutput` on a dedicated serial `DispatchQueue`
- Exposes `func start()` and `func stop()`
- Delegate callback: `var onSampleBuffer: (@Sendable (CMSampleBuffer) -> Void)?`
- Request `AVCaptureDevice.requestAccess(for: .video)` before starting

---

### Vision/HandPoseDetector.swift

Purpose: Receive sample buffers, run `VNDetectHumanHandPoseRequest`, detect punch events.

**Punch detection algorithm:**

Each frame, extract the hand bounding box area from the observation's recognized points (wrist + all fingertips). Track `previousArea: CGFloat`.

```
areaGrowthRate = (currentArea - previousArea) / previousArea
```

State machine (enum PunchPhase):
- `.idle` → `.extending` when `areaGrowthRate > 0.15` for 2+ consecutive frames
- `.extending` → `.retracting` when `areaGrowthRate < -0.05`  
- `.retracting` → `.idle` + **emit punch event** when `areaGrowthRate > -0.02` (stabilised)
- Reset to `.idle` if no hand detected for 10 frames

Use `VNDetectHumanHandPoseRequest` with `maximumHandCount = 1`.

Expose:
```swift
var onPunchDetected: (@Sendable () -> Void)?
```

All Vision processing on a background actor.

---

### Model/PunchSession.swift

```swift
@Observable
@MainActor
final class PunchSession {
    private(set) var punchCount: Int = 0
    private(set) var punchesPerSecond: Double = 0.0
    private(set) var sessionDuration: TimeInterval = 0.0
    private(set) var isActive: Bool = false

    // Ring buffer of last 20 punch timestamps for rolling speed calculation
    private var recentPunches: [Date] = []
    private var sessionStart: Date?
    private var displayLink: CADisplayLink?
    
    func recordPunch() { ... }   // increment count, append timestamp, start session if needed
    func reset() { ... }
    func startDisplayLink() { ... }  // update duration + pps every frame
    func stopDisplayLink() { ... }
    
    // punchesPerSecond = count of punches in last 3s window / 3.0
}
```

---

### UI/CameraPreviewView.swift

`UIViewRepresentable` wrapping `AVCaptureVideoPreviewLayer`:
- `.videoGravity = .resizeAspectFill`
- Connects to `CameraSession.session` (`AVCaptureSession`)

---

### UI/StatsOverlayView.swift

Full-screen overlay with a dark translucent panel at the bottom showing:

```
┌─────────────────────────────────┐
│  👊  247          3.2 /s        │
│       PUNCHES      SPEED        │
│         Session: 1:23           │
│    [  RESET  ]                  │
└─────────────────────────────────┘
```

- Large SF Symbols + numbers
- Animate count changes with `.contentTransition(.numericText())`
- `punchesPerSecond` formatted to 1 decimal
- Duration formatted as `m:ss`
- Reset button calls `session.reset()`

Use `.ultraThinMaterial` background, rounded corners, safe area aware.

---

### UI/ContentView.swift

- `@State private var session = PunchSession()`
- Initialise `CameraSession` and `HandPoseDetector` as `@State` properties
- Wire: `cameraSession.onSampleBuffer → detector.process(_:)` → `session.recordPunch()`
- `ZStack`: `CameraPreviewView` (full screen) + `StatsOverlayView` on top
- Call `cameraSession.start()` in `.task` and `cameraSession.stop()` in `.onDisappear`
- Handle camera permission denial with an overlay explaining how to enable in Settings

---

## Info.plist

Add:
```xml
<key>NSCameraUsageDescription</key>
<string>PunchCounter needs the front camera to detect and count your punches.</string>
```

---

## Swift 6 Concurrency Notes

- All `@MainActor` on `PunchSession` and UI views
- `CameraSession` uses `@unchecked Sendable` (manually managed with serial queue)
- `HandPoseDetector` runs on a background `actor`
- All closures crossing actor boundaries marked `@Sendable`
- No `DispatchQueue.main.async` — use `await MainActor.run { }` instead

---

## Build & Test Checklist

1. `xcodebuild -scheme PunchCounter -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` must succeed
2. No SwiftUI deprecation warnings
3. No data races (enable Thread Sanitizer)
4. Camera preview renders (simulator will show blank — that's OK)
5. Simulate punches by covering/uncovering the camera to trigger area growth events

---

## Bonus (implement if straightforward)

- Haptic feedback (`UIImpactFeedbackGenerator(.rigid)`) on each punch detection
- A subtle ring animation radiating from the punch point on detection

---

## Unit Tests

Create a `PunchCounterTests` target. No UI tests — unit tests only. All tests must pass with `xcodebuild test`.

### Test Structure

```
PunchCounterTests/
├── PunchSessionTests.swift
├── PunchPhaseStateMachineTests.swift
└── SpeedCalculationTests.swift
```

---

### PunchSessionTests.swift

Test `PunchSession` in isolation. Since it is `@MainActor`, use `@MainActor` on test class or wrap assertions in `await MainActor.run {}`.

```swift
@MainActor
final class PunchSessionTests: XCTestCase {
```

**Tests to implement:**

```swift
// Initial state
func test_initialState_isInactive_zeroStats()
// punchCount starts at 0, pps = 0, duration = 0, isActive = false

// First punch activates session
func test_recordPunch_firstPunch_activatesSession()
// After recordPunch(), isActive == true, punchCount == 1

// Count increments correctly
func test_recordPunch_multipleCallsIncrementCount()
// 5x recordPunch() → punchCount == 5

// Reset clears everything
func test_reset_clearsAllState()
// recordPunch() x3, then reset() → all properties back to initial values

// Ring buffer caps at 20
func test_recentPunches_cappedAtTwenty()
// recordPunch() x25, then access internal recentPunches.count via testable import
// count must be <= 20

// punchesPerSecond only counts last 3s
func test_punchesPerSecond_onlyCountsRecentWindow()
// Inject 5 "old" punches (timestamp - 10s) and 3 recent punches
// pps should reflect only the 3 recent ones → 3.0/3.0 = 1.0
// Requires PunchSession to accept injectable clock (Protocol or closure)
```

**Testability requirement:** Extract timestamp source into an injectable closure so tests can control time:

```swift
// In PunchSession:
var now: () -> Date = { Date() }  // injectable for tests
```

---

### PunchPhaseStateMachineTests.swift

Extract the punch phase state machine into a testable pure struct/class `PunchPhaseStateMachine` (separate from Vision processing):

```swift
struct PunchPhaseStateMachine {
    private(set) var phase: PunchPhase = .idle
    private var extendingFrameCount: Int = 0
    private var missedFrameCount: Int = 0

    // Returns true when a punch is completed
    mutating func update(areaGrowthRate: CGFloat?, handDetected: Bool) -> Bool
}
```

**Tests:**

```swift
func test_idle_toExtending_requiresTwoConsecutiveGrowthFrames()
// Single frame with rate 0.20 → phase still .idle (need 2 consecutive)
// Second frame with rate 0.20 → phase == .extending

func test_extending_toRetracting_onNegativeGrowth()
// Drive to .extending, then rate -0.10 → phase == .retracting

func test_retracting_toIdle_emitsPunch_onStabilisation()
// Full cycle: idle → extending → retracting → stabilise
// update() returns true exactly once at completion

func test_missingHandFrames_resetsToIdle()
// Drive to .extending, then handDetected=false for 10 frames → phase == .idle

func test_noFalsePositive_slowGrowth()
// rate 0.05 (below threshold) never transitions out of .idle

func test_fullPunchCycle_returnsTrue_exactlyOnce()
// Run complete valid punch sequence, assert update() returns true once total

func test_consecutiveCountResets_onNonExtendingFrame()
// rate 0.20 (frame 1), rate 0.02 (frame 2 — not extending), rate 0.20 (frame 3)
// Should NOT reach .extending because consecutive count was reset
```

---

### SpeedCalculationTests.swift

Test the rolling window speed logic independently via a helper or by using `PunchSession` with time injection.

```swift
func test_emptyWindow_speedIsZero()
func test_threePunchesInThreeSeconds_speedIsOne()
func test_tenPunchesInOneSecond_speedIsTen()
func test_oldPunchesExcluded_fromWindow()
// Mix of 5 punches at t-10s and 6 punches at t-1s → speed = 6/3 = 2.0
func test_speedUpdatesAsWindowSlides()
// Add punch at t=0, t=1, t=2, t=3 — at t=3, punch at t=0 drops out
```

---

### Test Helpers

Add a `TestClock.swift` helper in the test target:

```swift
final class TestClock {
    var current: Date = Date()
    func advance(by seconds: TimeInterval) { current += seconds }
    var now: () -> Date { { self.current } }
}
```

Use it to inject deterministic time into `PunchSession` and speed calculation tests.

---

### Build & Test Command

```bash
xcodebuild test \
  -scheme PunchCounter \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -testPlan PunchCounterTests
```

All tests must pass with 0 failures. No `XCTSkip` allowed.
