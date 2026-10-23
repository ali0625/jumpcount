import SwiftUI

struct WorkoutHistoryView: View {
    @ObservedObject var history: WorkoutHistory

    var body: some View {
        NavigationStack {
            Group {
                if history.records.isEmpty {
                    ContentUnavailableView(
                        "还没有训练记录",
                        systemImage: "figure.jumprope",
                        description: Text("手表结束一次跳绳训练后，记录会同步到这里。")
                    )
                } else {
                    List(history.records) { record in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.count.formatted() + " 次")
                                .font(.headline)
                            Text(record.date, format: .dateTime.year().month().day().hour().minute())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(durationText(record.duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("跳绳记录")
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
