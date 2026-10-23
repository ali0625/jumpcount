import SwiftUI

struct WatchWorkoutView: View {
    @ObservedObject var workout: WorkoutController

    var body: some View {
        VStack(spacing: 8) {
            Text("跳绳次数")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(workout.count.formatted())
                .font(.system(size: 46, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
            Text(elapsedText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Button(workout.isRunning ? "结束训练" : "开始跳绳") {
                workout.isRunning ? workout.stop() : workout.start()
            }
            .tint(workout.isRunning ? .red : .green)
        }
        .padding(.horizontal, 8)
    }

    private var elapsedText: String {
        let seconds = Int(workout.elapsed)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
