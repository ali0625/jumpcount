# 计数算法来源与真机校准

## 使用的开源实现

当前 `peakdetect-v1` 从 [har1eyk/peakdetect](https://github.com/har1eyk/peakdetect/blob/5e5a451cfff8d5aa8d95cf25c1db8eae022c36e3/peakdetect.py) 的 `peakdetect()` 移植为流式 Swift，固定提交 `5e5a451cfff8d5aa8d95cf25c1db8eae022c36e3`。上游基于 [Eli Billauer 的 peakdet](https://billauer.co.il/peakdet.html)，提供相对峰谷差值和 lookahead 确认；MIT 许可及版权声明保存在 [ThirdParty/peakdetect-LICENSE.txt](ThirdParty/peakdetect-LICENSE.txt)，同时打包到 App。

这是一种通用波峰检测算法，并非已经在 Apple Watch 跳绳场景训练或验证准确率的模型。Swift 实现保留上游的极值切换、前瞻确认与首个边界极值丢弃逻辑，将批处理改为仅保留 4 个样本的流式处理。外层继续检查非法值、倒退时间戳及采样中断，预热 15 个样本，按波峰时间执行 0.23 秒最小间隔。

输入为含重力的三轴合加速度，差值参数为 0.15 g、lookahead 为 3 个样本。移除了旧算法的高通/低通级联，以免把较小波峰压平；以相对峰谷差识别在偏高基线上的波峰。计数要等波峰回落并经过前瞻确认，所以显示有短暂延迟。

日志开始事件记录 `algorithm=peakdetect-v1`。新日志的 `filtered_g` 为 `magnitude_g - 1`，用来显示零中心信号；旧日志的该列是原滤波器输出。`is_jump` 在确认时刻记录，可能晚于实际波峰。训练结束前静止约 3 秒，以便确认尾部波峰。

## 已查阅但没有直接接入的实现

| 实现 | 核查结果 |
| --- | --- |
| [Maxime6/JumpR](https://github.com/Maxime6/JumpR) | 真正的 watchOS 工程，但检测仍为固定轴/合加速度阈值加 0.2 秒防抖；未发现许可证或精度验证数据 |
| [egehurturk/JumpRopeDetector](https://github.com/egehurturk/JumpRopeDetector) | 手机摄像头与人体姿态检测，不是腕上传感器算法 |
| [jjcheer/airpods_ropejumpping](https://github.com/jjcheer/airpods_ropejumpping) | 说明使用 AirPods，但本次检出的仓库快照缺少实际计数源文件 |
| [mwsanti/JumpRope](https://github.com/mwsanti/JumpRope) | MIT 的 Garmin 项目；当前代码对约 1 Hz 的超阈值读数按 2、3 次交替累计，与文档声称的 25 Hz 逐跳状态机不一致，未采用 |
| [ig248/pyampd](https://github.com/ig248/pyampd) | MIT 的多尺度 AMPD；离线比较对最大尺度较敏感，这两组样本未显示足够优势，暂未接入 |

## 2026-10-23 本机回放

| 数据 | 人工次数 | 旧算法记录 | 当前 Swift 回放 |
| --- | --- | --- | --- |
| 第一轮，约 9.4 秒 | 20 | 7 | 20 |
| 第二轮，约 19.1 秒，中间绊绳一次 | 20 | 12 | 25 |

同参数的上游 Python 参考回放也得到 20、25，与实际 Swift 计数代码一致。这两轮属于开发调参数据，不能当作独立精度验证；第二轮仍多计 5 次，绊绳、准备动作和腕部摆动的误识别需要新数据验证。没有给计数乘系数，也没有将人工目标次数写入算法。

共享包的 15 个测试覆盖噪声、每周期只计一次、小幅波峰、偏高基线、持续高加速度、防抖、采样中断、非法输入、持久化与日志写入。实际样本留在本机 `.watchos/exports`，不会上传 GitHub。

## 回放本机 CSV

在仓库目录的 WSL 中使用已准备的 Swift：

```bash
/opt/ropeskip/swift/usr/bin/swiftc \
  Packages/JumpCore/Sources/JumpCore/JumpCounter.swift \
  Packages/JumpCore/Sources/JumpCore/RelativePeakDetector.swift \
  tools/replay_counter.swift -o .watchos/replay-counter
.watchos/replay-counter .watchos/exports/日期时间/Workouts/训练.csv
```

回放读取原始 `magnitude_g` 和传感器时间戳，与手表共用同一份 Swift 代码，不使用旧 CSV 中的滤波值或跳跃标记作为输入。
