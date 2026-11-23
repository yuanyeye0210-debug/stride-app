import SwiftUI

@main
struct StrideWatchApp: App {
    @StateObject private var motion = WatchWorkoutMotionManager.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(motion)
        }
    }
}
