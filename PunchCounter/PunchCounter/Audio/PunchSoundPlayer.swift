import AudioToolbox

@MainActor
enum PunchSoundPlayer {
    static func playPunch() {
        AudioServicesPlaySystemSound(1104)
    }

    static func playMilestone() {
        AudioServicesPlaySystemSound(1025)
    }
}
