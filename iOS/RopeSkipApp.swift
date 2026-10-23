import SwiftUI

@main
struct RopeSkipApp: App {
    @StateObject private var history = WorkoutHistory()

    var body: some Scene {
        WindowGroup {
            WorkoutHistoryView(history: history)
        }
    }
}
