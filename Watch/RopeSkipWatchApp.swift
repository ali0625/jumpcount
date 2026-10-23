import SwiftUI

@main
struct RopeSkipWatchApp: App {
    @StateObject private var workout = WorkoutController()

    var body: some Scene {
        WindowGroup {
            WatchWorkoutView(workout: workout)
        }
    }
}
