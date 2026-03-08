import AVFoundation

final class CameraSession: NSObject, @unchecked Sendable {
    nonisolated let session = AVCaptureSession()
    private nonisolated let outputQueue = DispatchQueue(label: "com.punchcounter.camera-output")

    nonisolated(unsafe) var onSampleBuffer: (@Sendable (CMSampleBuffer) -> Void)?

    nonisolated func start() {
        outputQueue.async { [self] in
            configureSession()
            session.startRunning()
        }
    }

    nonisolated func stop() {
        session.stopRunning()
    }

    private nonisolated func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: outputQueue)
        output.alwaysDiscardsLateVideoFrames = true

        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
    }
}

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onSampleBuffer?(sampleBuffer)
    }
}
