import SwiftUI

@main
struct RopeSkipApp: App {
    @StateObject private var history = WorkoutSync()

    var body: some Scene {
        WindowGroup {
            WorkoutHistoryView(history: history)
        }
    }
}
