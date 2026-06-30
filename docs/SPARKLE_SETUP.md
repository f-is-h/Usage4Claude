# Sparkle 应用内更新 — 配置与发版流程

本项目使用 [Sparkle](https://sparkle-project.org) 实现应用内更新。用户可通过一键"安装更新"完成 EdDSA 签名校验与自动替换，告别手动"下载 DMG → 拖入 /Applications → 重启"的流程。

本文档涵盖一次性初始配置与每次发版的操作流程。

---

## 一次性初始配置（只需执行一次）

在发布首个集成 Sparkle 的版本之前，需要生成 EdDSA 签名密钥对，并将公钥写入 `Config/Info.plist`。

### 1. 下载 Sparkle 命令行工具

从 [github.com/sparkle-project/Sparkle/releases](https://github.com/sparkle-project/Sparkle/releases) 下载最新版本并解压。关键二进制文件位于 `bin/` 目录：

- `generate_keys` — 生成 EdDSA 密钥对（仅执行一次）
- `sign_update` — 在每次发版时对 DMG 签名

建议放到固定路径。构建脚本默认查找 `/tmp/sparkle-tools/bin/sign_update`，最简安装方式：

```bash
mkdir -p /tmp/sparkle-tools/bin
cp /path/to/extracted/Sparkle-*/bin/sign_update /tmp/sparkle-tools/bin/
cp /path/to/extracted/Sparkle-*/bin/generate_keys /tmp/sparkle-tools/bin/
chmod +x /tmp/sparkle-tools/bin/*
```

> `/tmp/` 在部分 macOS 配置下会被清空。若遇到此问题，可将二进制文件放到 `~/.local/bin/`（或任意自定义工具目录），并在运行 `scripts/build.sh` 时通过环境变量 `SIGN_UPDATE=/your/path/to/sign_update` 指定路径。

### 2. 生成密钥对

```bash
/tmp/sparkle-tools/bin/generate_keys
```

输出示例：

```
A pre-existing signing key was not found, so a new one has been generated and saved
in your keychain. Public key: hGTiB0kyn45HOB8WWKdAHc28+Bthe8Rv8O7asa4nG2c=
```

**私钥**保存在**登录 Keychain**（条目名称 `https://sparkle-project.org`），不会以明文形式落盘。`Public key:` 之后的字符串即为公钥。

### 3. 将公钥写入 Config/Info.plist

将 `Config/Info.plist` 中的占位符替换为实际公钥：

```xml
<key>SUPublicEDKey</key>
<string>REPLACE_WITH_YOUR_PUBLIC_KEY_AFTER_RUNNING_generate_keys</string>
```

替换为：

```xml
<key>SUPublicEDKey</key>
<string>hGTiB0kyn45HOB8WWKdAHc28+Bthe8Rv8O7asa4nG2c=</string>
```

提交后，**每一个后续 Sparkle 更新包都必须用对应私钥签名**——这是客户端拒绝篡改更新的信任锚点。

### 4. 备份私钥

将私钥导出为 `.p12` 并妥善保存（加密备份、1Password 等）。一旦私钥丢失，所有已安装的旧版本将无法接受后续更新（Sparkle 会拒绝公钥不匹配的签名）。

导出步骤：

```
钥匙串访问 → "login" 钥匙串 → 搜索 "sparkle-project" → 右键 → 导出
```

保存为 `.p12`，设置密码，存放在仓库以外。

---

## 每次发版流程

> **日常发版走 CI**：推送带 `[release]` 的 commit 后，GitHub Actions 会自动完成 DMG 签名、
> 更新 `appcast.xml`、创建 draft release，见 [DAILY_RELEASE_WORKFLOW.md](./DAILY_RELEASE_WORKFLOW.md)。
> 下面的手动流程仅用于本地出包或理解底层原理。

初始配置完成后，每次发版按以下流程操作：

1. **更新版本号**：修改 `Usage4Claude.xcodeproj/project.pbxproj` 中的 `MARKETING_VERSION`。`CURRENT_PROJECT_VERSION` 已配置为 `$(MARKETING_VERSION)`，Sparkle 比较版本时使用的 Build 号（`CFBundleVersion`）会自动跟随，**无需手动修改**。切勿将其固定为 `1` 等常数——否则两个不同版本共享相同 Build 号，Sparkle 无法区分，导致更新通知缺失或更新死循环。

2. **构建 DMG**：

   ```bash
   ./scripts/build.sh
   ```

   脚本末尾会执行 `Sparkle 签名` 步骤，输出类似：

   ```
       <enclosure
           url="https://github.com/f-is-h/Usage4Claude/releases/download/v3.2.0/Usage4Claude-v3.2.0.dmg"
           sparkle:edSignature="qZ0Y8nm..."
           length="9437184"
           type="application/octet-stream"/>
   ```

3. **将上述内容写入 `appcast.xml`**：作为新的顶部 `<item>`（置于所有现有条目之上），并填写 `<title>`、`<pubDate>`、`<sparkle:version>`、`<sparkle:shortVersionString>`、`<link>` 和 `<description>`。`appcast.xml` 顶部的模板注释展示了完整结构。`<description>` 支持 `sparkle:format="markdown"`，可直接用 Markdown 编写 Release Notes（Sparkle 2.9+ 可渲染）。

4. **提交、打 Tag、推送**，并在 GitHub 上创建附带 DMG 的 Release。

发布后，用户会在 24 小时内通过后台轮询收到更新提示，或通过"菜单 → 检查更新"立即触发。

---

## App 沙盒

应用以沙盒模式发布（`ENABLE_APP_SANDBOX = YES`）。以下三项配置确保 Sparkle 的一键安装在沙盒下正常工作：

1. **`Config/Usage4Claude.entitlements`**（通过 `CODE_SIGN_ENTITLEMENTS` 关联）授权：
   - `com.apple.security.app-sandbox`
   - `com.apple.security.network.client` — 允许 HTTPS 访问 API 与 appcast
   - `com.apple.security.temporary-exception.mach-lookup.global-name`，用于 `$(PRODUCT_BUNDLE_IDENTIFIER)-spks` / `-spki`，即 Sparkle 内置的 Installer 和 Status XPC 服务。`$(...)` 在构建时展开，自动跟随 Bundle ID。

2. **`SUEnableInstallerLauncherService = true`**（`Config/Info.plist` 中）启用沙盒兼容的安装启动器。

3. Sparkle 的 SwiftPM 集成会自动将 `Installer.xpc` 打包进 app bundle，无需额外配置。

`SUEnableDownloaderService` 未设置：Downloader XPC 仅在应用缺少 `network.client` 权限时才需要，本项目已授权该 entitlement。

> **注意（针对沙盒迁移前的旧版安装）：** 启用沙盒后，Keychain 访问分组发生变化，非沙盒构建保存的凭据在沙盒版中不可见——用户需通过浏览器登录重新认证一次。建议在首个沙盒版本的 Release Notes 中说明此情况。

---

## 为什么 Debug 构建跳过 Sparkle 签名？

`scripts/build.sh` 会在默认路径查找 `sign_update`，找不到时打印警告但**不中止构建**。这样即使本地没有安装 Sparkle CLI 工具，也能正常编译运行——Sparkle 签名只在实际发版时才有意义。
