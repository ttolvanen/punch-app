import Vision
import CoreMedia

nonisolated struct HandTracker: Sendable {
    var stateMachine = PunchPhaseStateMachine()
    var previousArea: CGFloat?
    var lastSeenFrame: Int = 0
}

actor HandPoseDetector {
    var onPunchDetected: (@Sendable () -> Void)?

    func setOnPunchDetected(_ handler: @escaping @Sendable () -> Void) {
        onPunchDetected = handler
    }

    private var leftTracker = HandTracker()
    private var rightTracker = HandTracker()
    private var frameCount: Int = 0
    private var isProcessing = false

    func process(_ sampleBuffer: CMSampleBuffer) {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        frameCount += 1

        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])

        let observations = request.results ?? []

        var leftSeen = false
        var rightSeen = false

        for observation in observations {
            let area = boundingBoxArea(from: observation)
            let chirality = observation.chirality

            switch chirality {
            case .left:
                leftSeen = true
                if processHand(tracker: &leftTracker, area: area) {
                    onPunchDetected?()
                }
            case .right:
                rightSeen = true
                if processHand(tracker: &rightTracker, area: area) {
                    onPunchDetected?()
                }
            case .unknown:
                // Route to whichever tracker was least recently updated
                if leftTracker.lastSeenFrame <= rightTracker.lastSeenFrame {
                    leftSeen = true
                    if processHand(tracker: &leftTracker, area: area) {
                        onPunchDetected?()
                    }
                } else {
                    rightSeen = true
                    if processHand(tracker: &rightTracker, area: area) {
                        onPunchDetected?()
                    }
                }
            @unknown default:
                break
            }
        }

        if !leftSeen {
            let _ = leftTracker.stateMachine.update(areaGrowthRate: nil, handDetected: false)
        }
        if !rightSeen {
            let _ = rightTracker.stateMachine.update(areaGrowthRate: nil, handDetected: false)
        }
    }

    private func processHand(tracker: inout HandTracker, area: CGFloat) -> Bool {
        var growthRate: CGFloat?
        if let prev = tracker.previousArea, prev > 0 {
            growthRate = (area - prev) / prev
        }
        tracker.previousArea = area
        tracker.lastSeenFrame = frameCount
        return tracker.stateMachine.update(areaGrowthRate: growthRate, handDetected: true)
    }

    private func boundingBoxArea(from observation: VNHumanHandPoseObservation) -> CGFloat {
        let jointNames: [VNHumanHandPoseObservation.JointName] = [
            .wrist, .thumbTip, .indexTip, .middleTip, .ringTip, .littleTip
        ]

        var points: [CGPoint] = []
        for name in jointNames {
            if let point = try? observation.recognizedPoint(name), point.confidence > 0.3 {
                points.append(point.location)
            }
        }

        guard points.count >= 2 else { return 0 }

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let width = (xs.max() ?? 0) - (xs.min() ?? 0)
        let height = (ys.max() ?? 0) - (ys.min() ?? 0)
        return width * height
    }
}
