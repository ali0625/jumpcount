# 跳绳计数：Windows 开发，GitHub macOS 编译

个人使用的 iPhone + Apple Watch SwiftUI App。Windows 编辑代码，GitHub Actions 编译真机目标，不需要在 Windows 安装或运行模拟器。最低目标为 iOS 17 / watchOS 10；这些是最低运行版本，并不要求手机降级。Runner 实际的 Xcode / SDK 版本会保存在构建日志中。

## 当前实现

- 手表显示次数和时长，手动开始、结束。
- 约 50 Hz 采集加速度，用滤波、阈值和最小间隔估算次数。算法仍需用真实跳绳数据校准。
- 每次训练写入本地 CSV，记录三轴加速度、滤波信号、跳跃标记、累计次数和开始/结束/传感器错误事件。
- 结束时先在手表保存训练摘要，再通过 WatchConnectivity 分别排队传送摘要和 CSV。手机离线也能保存，重新打开手表 App 时会重试。
- 手机本地保存历史，在训练详情中导出 CSV。摘要和文件可能先后到达；同步由系统安排，不保证即时送达。
- 手表提供“重试同步记录与日志”；重装手机 App 或接收失败后可使用。接收端按训练 UUID 去重。
- 计数、记录持久化、日志写入和接收文件复制均有 Swift 单元测试。

## 重要：免费账户与真机安装

当前 Actions 产物为 **未签名的真机 App / IPA**。扩展名为 IPA 不等于已经签名，直接下载仍不能安装到 iPhone 或 S10。

普通 Apple 账户可通过 Xcode Personal Team 在个人设备测试，免费描述文件有效期为 7 天，需要重新构建和安装。官方流程仍需能运行 Xcode 的 Mac；GitHub 云端构建机不能直接连接你本地的手机或手表，也不会替你完成 Personal Team 登录和安装。

Windows 第三方侧载工具有免费账户的 iPhone 签名能力，但本项目尚未验证它们能完整签名并安装内嵌 Watch App，尤其是你的 iOS 27.0.1 和 S10 的实际 watchOS 版本。不要把“iPhone 安装成功”当作“手表也能安装成功”。免费、纯 Windows 的 S10 安装链路仍待验证；借用兼容的 Mac 使用 Xcode 是已有官方流程的备选。

第一步记录手表实际 watchOS 版本，再验证签名和安装。不需要把 Apple 密码、验证码、证书或私钥放到 GitHub。

官方说明：[Apple 账户与 Personal Team](https://developer.apple.com/support/compare-memberships/)。

## GitHub Actions 编译

仓库已经初始化时，在此目录打开 PowerShell：

```powershell
git add .
git commit -m "Add device builds and workout logging"
git push
```

推送到 `main`、对 `main` 的 Pull Request，以及手动点击 **Actions → Apple device build → Run workflow** 都可触发。

工作流依次运行：

1. 打印 Xcode 和 SDK 版本。
2. `swift test --package-path Packages/JumpCore`，在 macOS 上测试共享逻辑，不启动模拟器。
3. 使用 XcodeGen 从 `project.yml` 生成工程。
4. 使用 `generic/platform=iOS` 编译 iPhone 和内嵌 Watch 真机目标，并关闭签名。
5. 验证 Watch App 确实包含在产物中，保存 App ZIP、未签名 IPA 和构建日志。

运行完成后的 artifacts：

| 名称 | 内容 |
| --- | --- |
| `ropeskip-device-unsigned` | 未签名 App ZIP 和 `RopeSkip-unsigned.ipa`，不能直接安装 |
| `ropeskip-build-diagnostics` | Xcode/SDK 信息、Swift 测试日志、真机构建日志和结果包；失败时也尽量保留 |

产物保留 3 天。公开仓库使用标准 GitHub-hosted runner 的构建计算资源免费；存储及私有仓库的免费额度另计。不要开启付费 larger runner 或购买构建服务。

## 日志调试（需要先完成真机签名安装）

1. 在 S10 打开 App，点击“开始跳绳”。第一轮先站立 2 秒，再跳 20 次并人工计数，点击“结束训练”。
2. 打开手机 App 并保持两台设备靠近。看到记录后进入“训练详情”。
3. 日志到达后点击“导出加速度与计数日志”，存入“文件”，再传到 Windows。日志和次数可能分批到达。
4. 若迟迟没有日志，在手表点击“重试同步记录与日志”。
5. 使用 Python 3.10+（不需额外依赖）分析：

```powershell
python tools/analyze_log.py "C:\你的日志目录\训练日志.csv" --expected 20
```

字段说明：

| 字段 | 含义 |
| --- | --- |
| `event` | `start`、`sample`、`stop`、`sensor_error` |
| `sensor_seconds` | 传感器单调时间戳，单位秒 |
| `elapsed_seconds` | 距本次第一条样本的时间，不是绝对时刻 |
| `x_g`、`y_g`、`z_g` | 原始三轴加速度，含重力，单位 g |
| `magnitude_g`、`filtered_g` | 合加速度及计数器滤波后的信号，单位 g |
| `is_jump`、`count` | 本条是否触发计数（0/1）、累计次数 |
| `detail` | 参数、训练 UUID、开始日期、错误信息或结束原因 |

日志包含运动数据，默认只在设备本地保存并在已配对设备间同步，不自动上传 GitHub。

## 当前限制

- 尚未加入 HealthKit 锻炼会话。进入后台时自动结束并保存，日志记为 `app_background`；不承诺灭屏、离开 App 后持续计数。
- CSV 每 25 行写入一次。正常结束时写完余量；进程意外终止可能丢失最后一批样本，并且未结束训练可能没有完整摘要。
- 日志写入失败会显示错误，次数仍继续；导出的文件可能不完整。
- 初始阈值为 0.25 g，最小计数间隔为 0.23 秒，预热为 15 个样本。阈值不代表已验证精度，双摇、绊绳和摆手可能误计。
- 尚未在真实 iPhone / S10 上验证签名安装、传感器精度、功耗与同步。

## 文件结构

`Watch/` 为手表界面和运动采集，`iOS/` 为手机历史和导出，`Shared/WorkoutSync.swift` 为配对设备同步，`Packages/JumpCore/` 为计数、模型、日志与持久化，`.github/workflows/build.yml` 为构建流程。
