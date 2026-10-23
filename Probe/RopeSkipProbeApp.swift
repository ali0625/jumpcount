import SwiftUI
import WatchKit

@main
struct RopeSkipProbeApp: App {
    var body: some Scene {
        WindowGroup { ProbeView() }
    }
}

private struct ProbeView: View {
    @State private var taps = 0
    @State private var started = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("跳绳安装测试").font(.headline)
                Text("按钮次数：\(taps)").monospacedDigit()
                Text(started, style: .timer).monospacedDigit()
                Button("点击并震动") {
                    taps += 1
                    WKInterfaceDevice.current().play(.click)
                }
                Button("重置") {
                    taps = 0
                    started = Date()
                }
                Text("能打开、计时、点击和震动，即通过基础运行验证。")
                    .font(.footnote)
                Text("这不是跳绳自动计数。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
