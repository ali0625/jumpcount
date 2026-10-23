import SwiftUI
import JumpCore

struct WorkoutHistoryView: View {
    @ObservedObject var history: WorkoutSync
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(history.message).foregroundStyle(.secondary)
                    if let error = history.errorMessage {
                        Text(error).foregroundStyle(.orange)
                    }
                }
                Section("训练记录") {
                  if history.records.isEmpty {
                    ContentUnavailableView(
                        "还没有训练记录",
                        systemImage: "figure.jumprope",
                        description: Text("手表结束一次跳绳训练后，记录会同步到这里。")
                    )
                  } else {
                    ForEach(history.records) { record in
                      NavigationLink {
                        WorkoutDetailView(record: record, sync: history)
                      } label: {
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
                }
            }
            .navigationTitle("跳绳记录")
            .toolbar {
                Button("检查连接") { history.synchronize() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { history.synchronize() }
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct WorkoutDetailView: View {
    let record: WorkoutRecord
    @ObservedObject var sync: WorkoutSync

    var body: some View {
        List {
            Section("本次训练") {
                LabeledContent("次数", value: "\(record.count) 次")
                LabeledContent("时长", value: "\(Int(record.duration)) 秒")
                LabeledContent("平均频率", value: "\(Int(record.cadence)) 次/分钟")
                Text(record.date, format: .dateTime.year().month().day().hour().minute())
            }
            Section("调试日志") {
                if sync.logIDs.contains(record.id), let url = try? sync.logURL(for: record.id) {
                    ShareLink(item: url) {
                        Label("导出加速度与计数日志", systemImage: "square.and.arrow.up")
                    }
                    Text("CSV 文件包含运动数据和计数结果，可存到“文件”或分享至电脑。")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("日志尚未收到。请保持手机与手表靠近，稍后查看；也可在手表点击重试同步。")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("训练详情")
    }
}
