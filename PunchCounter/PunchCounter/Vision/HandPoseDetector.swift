import Vision
import CoreMedia

actor HandPoseDetector {
    var onPunchDetected: (@Sendable () -> Void)?

    func setOnPunchDetected(_ handler: @escaping @Sendable () -> Void) {
        onPunchDetected = handler
    }

    private var stateMachine = PunchPhaseStateMachine()
    private var previousArea: CGFloat?

    func process(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])

        guard let observation = request.results?.first else {
            let _ = stateMachine.update(areaGrowthRate: nil, handDetected: false)
            return
        }

        let area = boundingBoxArea(from: observation)

        var growthRate: CGFloat?
        if let prev = previousArea, prev > 0 {
            growthRate = (area - prev) / prev
        }
        previousArea = area

        let punchDetected = stateMachine.update(areaGrowthRate: growthRate, handDetected: true)
        if punchDetected {
            onPunchDetected?()
        }
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
