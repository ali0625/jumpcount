# Windows 免费 Watch 安装实验

本机使用 xtool 官方项目的未合并 [PR #350](https://github.com/xtool-org/xtool/pull/350)，固定提交 `c46cd6a323d61f693ebe7354f5dcd91918e21f36`。分支提供独立 Watch App 的 `sign-watch` 与 Python 安装原型；不是官方稳定版保证支持的功能。本机已在 S10 / watchOS 27.0.1 验证测试包安装与启动。

WSL 源码另补入两项官方已合并改动：[Anisette 整理 #367](https://github.com/xtool-org/xtool/commit/2afd5307a4097ee5151d0765a9e0adb5241906d7) 和 [修复登录 -80046 的 #380](https://github.com/xtool-org/xtool/commit/e3ce2c402ec142d0d1bd0a0c9a20eb9c2ae8827c)。按此顺序应用，Package.resolved 由 SwiftPM 随 Package.swift 更新，不强行使用官方另一分支的锁文件。Watch 安装助手仍为原 PR 版本。

## 已准备的环境

- WSL 发行版 `Ubuntu-24.04`，Linux 用户 `ropeskip`；旧 20.04 已按用户要求移除。
- Swift 6.4.1：`/opt/ropeskip/swift`，下载后验证 Swift 发布签名。
- xtool 源码与构建：`/home/ropeskip/xtool`，入口 `/opt/ropeskip/run-xtool`。
- 原生依赖：`/opt/ropeskip/native`。libplist 2.6.0、glue 1.3.1、libusbmuxd 2.1.0、libtatsu 1.0.4、libimobiledevice `fa0f79190142bc309307967c058f89c1b36eb6b8`。
- Windows 独立 Python 3.12.10 与 pymobiledevice3 11.31.0：`.watchos/python`。未改系统 Python PATH。
- Windows 配对与安装助手：`.watchos/xtool-source/tools/watchos`。
- 私有手表信息：`.watchos/device.json`；配对密钥：`.watchos/watch-pairing`。整个 `.watchos/` 已被 Git 忽略。

本机验证：xtool 构建成功，21 项 Swift 测试通过；另有需要本地 Xcode.app 的验证被跳过。Windows 安装助手的 4 项 Python 测试通过，依赖一致性检查通过，手机与手表配对成功。上述测试不替代真机签名与启动验证。

补入登录修复后重新构建、21 项 Swift 测试和 SwiftLint 均通过（138 个 Swift 文件，0 违规）。已实际读取 S10 开发者模式为开启。

2026-10-23 本机真机验证：普通 Apple 账户登录成功，使用 GitHub Actions 编译的独立测试包完成签名，通过已配对的 iPhone 将其安装到 S10 / watchOS 27.0.1，安装进度 100%，手表 App 注册表确认存在。描述文件 CMS 校验通过，包含目标手表，有效期至 2026-10-30 17:41（北京时间）。设备主人已确认测试包能打开，按钮、计时和震动正常。

同日，实际传感器计数版「跳绳计数」已通过云端测试与编译、完成免费签名，并安装到 S10（注册表验证成功）。设备主人首轮人工跳 20 次，App 显示 7 次。已通过 USB iPhone 导出对应 JSON 与 CSV，确认保存 7 次、训练约 9.4 秒、465 个样本、约 49 Hz、无传感器错误和大于 0.1 秒的采样间隔。算法存在漏计，正在采集后续校准数据。

这些本机路径在新电脑需要重新准备，`watch.ps1` 不是通用依赖安装器。手机的 Apple USB 连接由 Windows“Apple 设备”应用提供；连接前需启动该应用，并让手机通过 USB 连接且信任电脑。

## 测试包

`Probe/` 是独立 Watch 测试 App，只验证打开、计时、点击和震动。`probe-project.yml` 使用 arm64、`WKApplication=true`、`WKWatchOnly=true`，不设置手机伴随标识，也不同时设置 `WKRunsIndependentlyOfCompanionApp`。

GitHub Actions 的 **Watch installation probe** 工作流在 macOS 26 / Xcode 26.6 编译，无需本地模拟器。成功运行：[39930287951](https://github.com/ali0625/jumpcount/actions/runs/39930287951)。产物下载后放在 `.watchos/apps/RopeSkipProbe.app`，仍需要本地签名。

## 实际计数版

`standalone-project.yml` 从现有 `Watch/`、`Shared/` 与 JumpCore 生成独立手表工程，最低 watchOS 26，使用 `ROPE_STANDALONE` 编译条件关闭手机同步。App 名称为「跳绳计数」，训练摘要及加速度 CSV 保存在手表本地，界面显示最近 5 次训练。此版本暂不连接手机 App；CSV 可在 Windows 经 USB iPhone 导出。

**Standalone Watch jump counter** 工作流运行 Swift 单元测试，再用 macOS 26 / Xcode 26.6 编译 arm64 真机包。成功运行：[39934051970](https://github.com/ali0625/jumpcount/actions/runs/39934051970)。下载 `watch-standalone-unsigned`，解压外层 artifact 和内层 ZIP，将 `RopeSkipStandalone.app` 放在 `.watchos/apps/`。产物保留 3 天，过期可手动重新运行工作流。

首次使用：打开「跳绳计数」→「开始跳绳」→静止 2 秒→人工数 20 次实际跳绳→「结束训练」，核对次数和下方最近训练。当前没有 HealthKit 锻炼会话，进入后台会结束训练；测试时保持 App 在前台。安装成功不代表计数精度已验证。

## 本机操作顺序

在仓库目录打开 PowerShell：

```powershell
.\tools\watch.ps1 Check
.\tools\watch.ps1 Pair
.\tools\watch.ps1 DeveloperMode
```

Pair 时解锁手机与手表，并在手表接受单独的“信任”提示。DeveloperMode 只请求显示开关，不自动开启。然后在手表本机“设置 → 隐私与安全性”（某些版本为“隐私”）底部开启开发者模式，重启并确认，再解锁手表。重新运行 Pair 应显示 `developer_mode: true`。

```powershell
.\tools\watch.ps1 Login
.\tools\watch.ps1 Sign
.\tools\watch.ps1 Install
```

Login 会在当前终端交互式登录；普通免费账户使用密码模式。密码与验证码只在本机终端输入，不发给聊天、不存脚本、不放 GitHub Secrets。xtool 登录状态和开发签名密钥留在 WSL 用户的本地存储中。

新官方登录实现使用 `https://mac-ani.jkcoxson.com` 的 Omnisette 服务生成随机设备的 Anisette 登录数据，服务接收相应随机标识和 provisioning 数据；按源码账户密码和验证码仍只发给 Apple。这是实际使用的第三方依赖，并非全程只连接 Apple。旧 Android Anisette 方式可能返回 `-80046`，已通过上述官方改动替换，不应反复重试旧版本。

Sign 对指定 Watch `.app` 就地签名，并注册当前手表与申请描述文件。Install 通过已配对的 USB iPhone 安装到手表并验证注册结果。两条命令默认使用 `.watchos/apps/RopeSkipStandalone.app`，即「跳绳计数」。如要重新安装测试包，分别加上 `-AppPath '.watchos/apps/RopeSkipProbe.app'`。

免费描述文件通常 7 天过期，需重新签名和安装。脚本会检查命令退出码；签名失败时不要继续安装。该分支拒绝自动撤销已有开发证书；如遇证书占用，先查看错误再决定，不要盲目撤销。

## 从 Windows 导出运动日志

无需先安装手机伴随 App。保持 USB iPhone 连接且已信任、手表在附近并已解锁，在仓库目录运行：

```powershell
.\.watchos\python\python.exe tools/watch_export.py
```

脚本通过已配对手表的 House Arrest 服务，只下载「跳绳计数」的 `Documents/Workouts` 到 `.watchos/exports/日期时间/Workouts/`，不修改手表数据。目标包标识从本机已签名 App 的 Info.plist 读取，因此须保留 `.watchos/apps/RopeSkipStandalone.app`。CSV 和摘要 JSON 都属于私人运动数据，默认不会被 Git 跟踪。

使用 `.\.watchos\python\python.exe tools/analyze_log.py 日志路径.csv --expected 20` 分析。首次实际导出与分析已在本机成功。

## 与跳绳项目的关系

现有 iPhone + 内嵌 Watch 的工程保留，同一提交的伴随版构建也已通过；此安装路线目前仅验证独立 Watch 包。传感器计数版复用现有计数和持久化代码，实际精度、功耗、后台行为与伴随版手机同步仍需要分别验证。

原型暂不支持自动启动或断点调试。Swift 构建日志在 `/home/ropeskip/logs/xtool-build.log`，测试日志在 `/home/ropeskip/logs/xtool-test.log`；运动日志使用项目原有 CSV 方案，独立版已验证可由 Windows 导出。
