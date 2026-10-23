# 跳绳 App 开发交接：2026-10-23

## 给新对话的任务

请先阅读此文件、`ALGORITHM.md` 和 `XTOOL.md`，接续这个项目。用户要在 Windows 11 上开发供自己使用的 iPhone + Apple Watch 跳绳计数 App，普通免费 Apple 账户，没有 Mac。免费编译、签名、安装和读取真实日志的链路已经打通，**主要阻碍是动作识别算法，计数功能还没有达到可用状态**。

用户明确要求：**优先搜索和复用已有算法，不要从零凭直觉开发；不要不停调阈值、让用户反复试跳。** 最新一轮用户因效果差提前结束，随后要求再分析一次并输出交接总结，去吃饭，本轮在此结束。恢复开发时先汇报已有结论，继续做不依赖本人测试的研究与离线分析。

## 工程、设备与当前安装状态

- 工作区：`C:\Users\Admin\Documents\Codex\2026-10-22\ni-h-4`
- Git 仓库：上述目录下的 `outputs\RopeSkip`
- 远程：<https://github.com/ali0625/jumpcount.git>，分支 `main`。
- iPhone：iOS 27.0.1；Apple Watch：S10，watchOS 27.0.1（24R365）。
- 手机 USB 已连接、电脑已获信任，手表也已信任此电脑，开发者模式已开启。重新连接时需本人解锁设备。
- 手表上目前是「跳绳计数」**0.2 / build 2**，使用通用 peakdetect，已收到失败反馈，**不是可用版本**。
- 旧「跳绳安装测试」已按用户要求卸载，服务端注册表确认不存在。它此前已由用户确认启动、按钮、计时和震动正常。
- 0.2 是覆盖更新，训练历史仍在手表；没有卸载正式计数 App。
- 当前免费描述文件到期：**2026-10-30 18:10 北京时间**，届时需要重新签名、安装。无需重新搭建整套环境。
- 用户要求卸载旧 Ubuntu 20.04，已经完成；只保留 Ubuntu-24.04。

## 三轮实测与这次分析

| 数据 | 实际动作 | App 记录 | 结论 |
| --- | --- | --- | --- |
| 第一轮，旧算法，约 9.43 秒 | 用户确认拿绳跳 20 次 | 7 次 | 明显漏计；465 样本，约 49.4 Hz |
| 第二轮，旧算法，约 19.11 秒 | 用户确认 20 次，中间绊一次 | 12 次 | 仍漏计；952 样本 |
| 第三轮，0.2，约 10.67 秒 | 摆手和未完成的跳绳，用户没跳满 20 次即结束 | 7 次 | 用户反馈轻微动手误计、正常跳绳漏计；实际次数未知 |

最新一轮有 528 样本、49.6 Hz，没有传感器错误、超过 0.1 秒的数据间隔或倒退时间戳，手动结束。确认计数事件约在 1.33、1.73、3.01、5.00、6.49、9.32、9.84 秒。旧算法回放同一文件得到 2 次，不能据此认为旧算法就正确。

现有程序正常采集、存储和显示，但它只用合加速度的波峰推断跳绳，缺少“是否正在跳绳”的活动识别。现有日志没有陀螺仪、重力向量或分离后的用户加速度，也没有逐次跳跃与摆手的时间标注。不能仅凭这些数据认定每个误计发生在哪个动作上。不要把第三轮标成实际 20 次或实际 0 次。

## 算法尝试、来源与教训

1. 原算法：50 Hz 加速度合模，基线 EMA 0.04、信号 EMA 0.4，阈值 0.25 g、迟滞 0.4 倍、最小间隔 0.23 秒、预热 15 样本。小波峰被压平且高基线会合并周期；单降阈值回放仍不能解决漏计。
2. 0.2：移植 [har1eyk/peakdetect](https://github.com/har1eyk/peakdetect) 的 MIT 实现，固定 `5e5a451cfff8d5aa8d95cf25c1db8eae022c36e3`，源自 Billauer peakdet。保留相对峰谷差、3 样本前瞻确认、首个边界极值丢弃；移除旧滤波，delta=0.15 g，外层保留 0.23 秒间隔及输入校验。Swift 与 Python 参考回放前两轮都得到 **20、25**。
3. 15 项共享包测试通过，证明基础程序行为，但没有证明跳绳识别正确；第三轮真实反馈已否定它的可用性。**旧日志回放接近人工次数不是活动识别准确率，也不能替代新数据验证。**

实现位于 `Packages/JumpCore/Sources/JumpCore/RelativePeakDetector.swift` 和 `JumpCounter.swift`；许可证在 `ThirdParty/peakdetect-LICENSE.txt`，也已打包进 App。`MotionLog.swift` 开始事件记录 `algorithm=peakdetect-v1`，新版 `filtered_g` 是合加速度减 1 g，旧版该列才是旧滤波输出。`is_jump` 是峰值确认时刻，晚于实际峰值。

已查阅：

- `Maxime6/JumpR`：真 watchOS 工程，但也是固定阈值，未发现许可或腕部精度数据。
- `egehurturk/JumpRopeDetector`：摄像头姿态识别，非腕部。
- `jjcheer/airpods_ropejumpping`：说明是 AirPods，但检出源码缺实际计数实现。
- `mwsanti/JumpRope`：MIT Garmin 项目；代码对约 1 Hz 的超阈值读数交替加 2、3 次，与文档逐跳描述不一致，未采用。
- `ig248/pyampd`：MIT 多尺度峰值检测，对两轮数据的尺度设置敏感，没表现出可靠优势，未接入。

以上仓库及离线比较脚本在工作区 `work/algorithm-research/`，不在 App Git 仓库中。详情在 `ALGORITHM.md`。目前**没有已验证的成熟腕部跳绳识别实现**，不要向用户声称已经找到。

下一步应先查找有源码、明确许可及真实腕部验证证据的运动识别实现，核查需要加速度、陀螺仪、姿态还是训练模型。必要时再设计多信号采集和有时间标注的对照动作；不能把增加陀螺仪说成必然修复。若没有可直接用的开源方案，应如实说明，不要把通用峰值检测包装成成熟跳绳算法。用户暂时休息，不要继续要求动作测试。

## 免费构建与安装链路：已经成功，无需重建

Windows 编辑 Swift → GitHub Actions macOS 26 / Xcode 26.6 编译独立 watchOS arm64 包 → WSL xtool 普通 Apple 账户签名 → Windows Python 经 USB iPhone 的 Companion Proxy 安装到 S10。

- `standalone-project.yml`：最低 watchOS 26，独立 Watch-only 工程，bundle `com.ali0625.ropeskip.standalone`；`ROPE_STANDALONE` 关闭 WCSession。
- `.github/workflows/watch-standalone.yml`：**Standalone Watch jump counter**；运行共享包测试、编译、核验元数据/arm64/许可证并打 ZIP。
- 0.2 成功构建：<https://github.com/ali0625/jumpcount/actions/runs/39936654841>
- 同提交的 iPhone + 内嵌 Watch 构建也成功：<https://github.com/ali0625/jumpcount/actions/runs/39936655074>
- 构建产物名 `watch-standalone-unsigned`，里面是 `RopeSkipStandalone-unsigned.zip`，需解两层，保留 3 天。
- `project.yml` 和 `.github/workflows/build.yml` 保留 iPhone + Watch 伴随工程；尚未验证该伴随包的免费签名安装与同步。
- 独立版训练/CSV 保存在手表，界面显示最近 5 次；手机 App 暂未安装/打通。
- 没有 HealthKit 锻炼会话，进入后台会结束训练并保存，不支持承诺灭屏/后台持续计数。

在 **仓库目录**运行 PowerShell：

```powershell
.\tools\watch.ps1 Check
.\tools\watch.ps1 Sign
.\tools\watch.ps1 Install
.\.watchos\python\python.exe tools/watch_export.py
```

`Sign` 就地签名；`Install` 仅在签名成功后运行，默认 App 路径 `.watchos/apps/RopeSkipStandalone.app`。签名后标识会带 xtool 前缀，导出脚本自动读取本机签名包的 Info.plist，**不要硬编码账户前缀**。当前签名包保留在该位置；旧 0.1 本机备份为 `.watchos/apps/RopeSkipStandalone-v01.app`。

`watch_export.py` 已实测通过 House Arrest 读取该 App 的 `Documents/Workouts`，不修改手表数据。输出到 `.watchos/exports/日期时间/Workouts/`，包含 JSON 和 CSV，整个 `.watchos/` 已被 Git 忽略，禁止提交运动原始数据、配对密钥或签名凭证。

最新完整导出：

```text
.watchos/exports/20261023-181252/Workouts/
  26FCE812-0F79-4B97-BB19-29557D54B64C.csv  第一轮
  40702B28-600C-4735-BC9F-E71020DFF9A5.csv  第二轮
  FC60CBCF-9804-4BFB-9D1B-C6D1EE88C04E.csv  第三轮/失败反馈
```

每份都有同名 JSON 摘要。分析方法：

```powershell
.\.watchos\python\python.exe tools/analyze_log.py 日志路径.csv
```

只有人工次数确定的前两轮可以加 `--expected 20`。Swift 实际算法回放方式见 `ALGORITHM.md` 和 `tools/replay_counter.swift`。

## 本机环境与登录修复

- WSL `Ubuntu-24.04`，Linux 用户 `ropeskip`。
- Swift 6.4.1：`/opt/ropeskip/swift/usr/bin/swift`。
- xtool 源码：`/home/ropeskip/xtool`；入口 `/opt/ropeskip/run-xtool`。
- 原生库：`/opt/ropeskip/native`，库版本在 `XTOOL.md`。
- 采用 xtool 官方仓库的**未合并 PR #350** Watch 分支，固定基础提交 `c46cd6a323d61f693ebe7354f5dcd91918e21f36`。用户已知情授权实验路线；不要误称官方稳定版原生支持 Watch。
- WSL 另按顺序补入两项官方登录修复：`2afd5307a4097ee5151d0765a9e0adb5241906d7`（#367）和 `e3ce2c402ec142d0d1bd0a0c9a20eb9c2ae8827c`（#380）。`Package.resolved` 由 SwiftPM 更新。
- 用户此前遇到 Apple `-80046`，修复后已登录成功；**不要退回旧 Android Anisette 登录实现**。
- 新登录使用 `https://mac-ani.jkcoxson.com` 生成 Anisette，用户已被告知；按源码账户密码/验证码仍只发送 Apple。
- xtool 21 项 Swift 测试及 SwiftLint 通过；Windows 安装助手 4 项测试通过。
- Windows 便携 Python 3.12.10：`.watchos/python/python.exe`；pymobiledevice3==11.31.0。
- Python `_pth` 已包含 `../xtool-source/tools/watchos`，能导入 WatchConnection。
- USB 驱动来自 Windows「Apple 设备」，需保持应用已启动。它并非老版 iTunes 服务，不要因没有 Apple Mobile Device Service 而重装整套环境。

登录已保留在本机。**不要读取/输出凭据内容，不要让用户把密码或 2FA 发到聊天或 GitHub。** 确需登录时 `tools/watch.ps1 Login` 会在本机交互终端输入。

## 网络、GitHub 与开发注意事项

- Windows 代理 `127.0.0.1:8080`。推送已可用：

```powershell
git -c http.proxy=http://127.0.0.1:8080 -c http.version=HTTP/1.1 push origin main
```

- `gh` 不作为必需工具；之前使用 Git Credential Manager 取 GitHub 凭据，仅在内存中用于 `api.github.com`，从未打印。不要把 Authorization 手动转发到第三方 artifact blob URL。
- Artifact 下载曾遇到 blob `ServerBusy Egress`，在 GitHub API 的 `archive_download_url` 添加 `?cache=当前Unix秒`，读取 302 Location 再单独下载成功。
- WSL NAT 无法直接连接 Windows localhost 代理。之前借助仅监听 WSL `127.0.0.1:28123` 的 socat + `work/xtool-setup/windows-proxy-stdio.py` 透传 Windows 代理完成构建。临时 socat **已停止**，常规签名和 Apple 登录不依赖它，不要无故重开。
- 不需新开子代理或新对话；用户此前没有要求委派。
- 所有原始 App、签名包、配对信息和日志都在忽略目录 `.watchos/`，不要加入版本控制。
- 实际 Swift 共享包验证可在仓库目录运行：

```powershell
wsl -d Ubuntu-24.04 -u ropeskip --exec /opt/ropeskip/swift/usr/bin/swift test --package-path Packages/JumpCore -j 4
```

截至交接已通过 15 项测试；Swift 测试和云端编译成功不等于运动识别准确。

## 关键提交与继续工作的边界

- `3597da4`：Windows 运动日志导出与正式包默认安装路径。
- `4287617`：当前 0.2 / peakdetect 移植、15 测试、来源许可、回放工具，两项云端构建成功。
- 本交接文档及最新失败结论会另作 `[skip ci]` 文档提交。

到此已做完用户本轮要求的“再分析一次并总结”，**没有继续修改/安装新算法，也没有宣称修复完成**。下次继续的重点是有依据的腕部动作识别方案；不要再搭建已打通的安装环境，也不要让用户重复登录。
