import SwiftUI

struct WatchWorkoutView: View {
    @ObservedObject var workout: WorkoutController
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
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
            Button(workout.hasUnsavedRecord ? "重试保存" : workout.isRunning ? "结束训练" : "开始跳绳") {
                if workout.hasUnsavedRecord { workout.retrySave() }
                else if workout.isRunning { workout.stop() }
                else { workout.start() }
            }
            .tint(workout.isRunning ? .red : .green)
            if let error = workout.errorMessage {
                Text(error).font(.caption2).foregroundStyle(.orange)
            }
            if !workout.isRunning {
                WatchSyncStatus(sync: workout.sync)
                Text("离开 App 后本次训练会自动结束")
                    .font(.caption2).foregroundStyle(.secondary)
            }
          }
          .padding(.horizontal, 8)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { workout.stop(reason: "app_background") }
            if phase == .active { workout.sync.synchronize() }
        }
    }

    private var elapsedText: String {
        let seconds = Int(workout.elapsed)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct WatchSyncStatus: View {
    @ObservedObject var sync: WorkoutSync

    var body: some View {
        VStack(spacing: 4) {
            Text("本机保存 \(sync.records.count) 次训练").font(.caption2)
            Text(sync.message).font(.caption2).foregroundStyle(.secondary)
            if let error = sync.errorMessage {
                Text(error).font(.caption2).foregroundStyle(.orange)
            }
            Button("重试同步记录与日志") { sync.synchronize(retryAll: true) }
                .font(.caption2)
        }
    }
}
