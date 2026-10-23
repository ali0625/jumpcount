# Windows 免费 Watch 安装实验

本机使用 xtool 官方项目的未合并 [PR #350](https://github.com/xtool-org/xtool/pull/350)，固定提交 `c46cd6a323d61f693ebe7354f5dcd91918e21f36`。分支提供独立 Watch App 的 `sign-watch` 与 Python 安装原型；不是官方稳定版保证支持的功能。作者验证的是 Ultra 2；本机目标是 S10 / watchOS 27.0.1，需实际验证安装与启动。

## 已准备的环境

- WSL 发行版 `Ubuntu-24.04`，Linux 用户 `ropeskip`；旧 20.04 已按用户要求移除。
- Swift 6.4.1：`/opt/ropeskip/swift`，下载后验证 Swift 发布签名。
- xtool 源码与构建：`/home/ropeskip/xtool`，入口 `/opt/ropeskip/run-xtool`。
- 原生依赖：`/opt/ropeskip/native`。libplist 2.6.0、glue 1.3.1、libusbmuxd 2.1.0、libtatsu 1.0.4、libimobiledevice `fa0f79190142bc309307967c058f89c1b36eb6b8`。
- Windows 独立 Python 3.12.10 与 pymobiledevice3 11.31.0：`.watchos/python`。未改系统 Python PATH。
- Windows 配对与安装助手：`.watchos/xtool-source/tools/watchos`。
- 私有手表信息：`.watchos/device.json`；配对密钥：`.watchos/watch-pairing`。整个 `.watchos/` 已被 Git 忽略。

本机验证：xtool 构建成功，21 项 Swift 测试通过；另有需要本地 Xcode.app 的验证被跳过。Windows 安装助手的 4 项 Python 测试通过，依赖一致性检查通过，手机与手表配对成功。上述测试不替代真机签名与启动验证。

这些本机路径在新电脑需要重新准备，`watch.ps1` 不是通用依赖安装器。手机的 Apple USB 连接由 Windows“Apple 设备”应用提供；连接前需启动该应用，并让手机通过 USB 连接且信任电脑。

## 测试包

`Probe/` 是独立 Watch 测试 App，只验证打开、计时、点击和震动。`probe-project.yml` 使用 arm64、`WKApplication=true`、`WKWatchOnly=true`，不设置手机伴随标识，也不同时设置 `WKRunsIndependentlyOfCompanionApp`。

GitHub Actions 的 **Watch installation probe** 工作流在 macOS 26 / Xcode 26.6 编译，无需本地模拟器。成功运行：[39930287951](https://github.com/ali0625/jumpcount/actions/runs/39930287951)。产物下载后放在 `.watchos/apps/RopeSkipProbe.app`，仍需要本地签名。

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

Sign 对指定 Watch `.app` 就地签名，并注册当前手表与申请描述文件。Install 通过已配对的 USB iPhone 安装到手表并验证注册结果；最后还需本人打开手表上的“跳绳安装测试”，实际验证按钮和震动。

免费描述文件通常 7 天过期，需重新签名和安装。脚本会检查命令退出码；签名失败时不要继续安装。该分支拒绝自动撤销已有开发证书；如遇证书占用，先查看错误再决定，不要盲目撤销。

## 与跳绳项目的关系

现有 iPhone + 内嵌 Watch 的工程保留。先验证上述独立测试包，再接入跳绳传感器计数；此时不能把“测试包已编译”当作“S10 已安装成功”，也不能把“手表注册成功”当作“计数准确”。

原型暂不支持自动启动或远程调试。Swift 构建日志在 `/home/ropeskip/logs/xtool-build.log`，测试日志在 `/home/ropeskip/logs/xtool-test.log`；运动日志仍使用项目原有 CSV 方案。
