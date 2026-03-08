import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var session = PunchSession()
    @State private var cameraSession = CameraSession()
    @State private var detector = HandPoseDetector()
    @State private var cameraPermissionDenied = false

    var body: some View {
        ZStack {
            CameraPreviewView(session: cameraSession.session)
                .ignoresSafeArea()

            StatsOverlayView(session: session)

            MilestoneAnimationView(session: session)

            if cameraPermissionDenied {
                cameraPermissionOverlay
            }
        }
        .task {
            await setupDetector()
            await checkPermissionAndStart()
        }
        .onDisappear {
            cameraSession.stop()
            session.stopDisplayLink()
        }
    }

    private func setupDetector() async {
        let localSession = session
        await detector.setOnPunchDetected {
            Task { @MainActor in
                localSession.recordPunch()
            }
        }
        let localDetector = detector
        cameraSession.onSampleBuffer = { buffer in
            Task {
                await localDetector.process(buffer)
            }
        }
    }

    private func checkPermissionAndStart() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraSession.start()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                cameraSession.start()
            } else {
                cameraPermissionDenied = true
            }
        default:
            cameraPermissionDenied = true
        }
    }

    private var cameraPermissionOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Camera Access Required")
                .font(.title2.bold())
            Text("PunchCounter needs the front camera to detect and count your punches. Please enable camera access in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(24)
    }
}
