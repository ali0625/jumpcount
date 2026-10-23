# 跳绳计数

个人使用的 iPhone + Apple Watch 跳绳计数 App。代码可在 Windows 上编辑；GitHub Actions 使用 macOS runner 生成 Xcode 工程并编译 iOS 与 watchOS 模拟器版本。

## 当前功能

- 手表端开始和结束训练，使用加速度计估算跳绳次数并显示训练时长。
- 结束训练后，通过 WatchConnectivity 把训练结果排队发送到 iPhone。
- iPhone 保存训练记录到本机，并显示次数、日期和时长。
- 计数算法和训练记录模型位于共享的 Swift Package，并带有基础单元测试。
- 计数阈值只是初始值，必须结合实际跳绳测试校准。

## 在 Windows 上编辑

用 Visual Studio Code 或其他编辑器打开本文件夹。Swift 文件可以正常编辑；Windows 本机不负责编译 Apple 平台目标。

## 用 GitHub Actions 编译

1. 在 GitHub 创建一个空仓库，不要勾选自动生成 README、许可证或 `.gitignore`。
2. 在本文件夹打开 PowerShell，执行：

   ```powershell
   git init -b main
   git add .
   git commit -m "Initial rope skipping app"
   git remote add origin https://github.com/你的用户名/你的仓库名.git
   git push -u origin main
   ```

   第一次提交前，如果 Git 提示缺少作者信息，用你自己的名字和邮箱设置 `git config --global user.name` 与 `git config --global user.email`。推送时用浏览器完成 GitHub 登录；不要把访问令牌写进命令或项目文件。

3. GitHub 页面打开仓库的 **Actions** 标签，查看 `Apple build` 工作流。
4. 构建成功后，从工作流运行页面下载 `ropeskip-simulator-build` artifact。它用于模拟器验证，不是可直接安装到手表的签名包。

之后每次推送到 `main` 或向 `main` 提交 Pull Request，都会自动运行构建。也可以在 **Actions → Apple build → Run workflow** 手动触发。

## 真机安装说明

当前工作流刻意关闭代码签名，只验证工程能否编译，因此还不能安装到 iPhone 或 Apple Watch。真机安装需要加入开发签名和对应设备配置；免费 Apple 开发者个人团队的签名通常 7 天到期，届时需重新签名安装。第一次配置签名时不要把 Apple 密码、证书私钥或恢复码提交到仓库。

## 重要限制

- 当前版本在训练界面运行期间采集手表加速度数据；尚未加入 HealthKit 锻炼会话，锁屏或离开 App 时的持续计数需要后续实现并真机验证。
- 跳绳动作检测是待校准的启发式算法。绊绳、双摇、换手和其他手臂动作可能造成漏计或误计。
- GitHub Actions 模拟器构建不等于在 S10 上安装、传感器采集和 iPhone/手表配对同步已验证。
