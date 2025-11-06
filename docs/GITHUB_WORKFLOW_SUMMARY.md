# Usage4Claude - GitHub Workflow 自动化发布总结文档

> 完整记录从需求讨论到最终实现的所有决策和配置

**创建日期**: 2025-11-02  
**版本**: 1.0  
**状态**: 已完成实现

---

## 📋 目录

1. [需求背景](#需求背景)
2. [讨论的所有问题与决策](#讨论的所有问题与决策)
3. [创建的文件清单](#创建的文件清单)
4. [配置清单](#配置清单)
5. [测试步骤](#测试步骤)
6. [日常使用流程](#日常使用流程)
7. [故障排除](#故障排除)

---

## 需求背景

**目标**: 创建一个GitHub Actions Workflow，实现以下自动化流程：
- 在推送代码后自动编译、打包、创建Release
- 最小化手动操作，提高发布效率
- 保持灵活性，允许最后手动确认

**约束条件**:
- 单人开发，免费GitHub账号
- 使用自签名证书
- 需要保持CHANGELOG和Release Notes的独立性

---

## 讨论的所有问题与决策

### 问题1: 触发方式

**讨论内容**: 如何触发workflow？手动推送标签 vs 推送到main自动化 vs 手动触发按钮

**最终决定**: ✅ **推送到main分支自动触发**
- 使用commit message关键字 `[release]` 或 `[RELEASE]` 触发
- 同时检测CHANGELOG.md文件变更
- 支持test-release分支用于测试
- 支持手动触发（带Dry Run选项）

**理由**:
- 最大化自动化，减少手动步骤
- 单人开发，不需要复杂的PR流程
- 关键字提供了明确的触发控制

---

### 问题2: 版本号来源与验证

**讨论内容**: 从哪里读取版本号？如何确保版本号一致？

**最终决定**: ✅ **从CHANGELOG提取，验证Xcode版本匹配**
- 从CHANGELOG.md提取最新版本号
- 从Xcode项目读取MARKETING_VERSION
- 对比两者，不匹配立即失败并报错

**理由**:
- CHANGELOG是版本历史的权威来源
- 双重验证确保版本号准确性
- 避免版本号不一致导致的问题

---

### 问题3: Release Notes内容策略

**讨论内容**: CHANGELOG和Release Notes的关系？是否整合？

**最终决定**: ✅ **保持独立，各司其职**

**CHANGELOG.md** (开发者视角):
- 技术性描述
- 结构化（Added/Changed/Fixed）
- 面向开发者和维护者

**Release Notes** (用户视角):
- 用户友好描述
- 包含emoji和丰富格式
- 包含Installation指南
- 包含链接和导航

**workflow行为**:
- 自动生成Release Notes模板（Installation等固定部分）
- 用户手动添加用户友好的描述
- 创建Draft Release，等待手动完善

**理由**:
- 两者受众不同，内容侧重点不同
- 保持灵活性，允许针对用户优化表达
- 避免重复劳动，自动生成固定部分

---

### 问题4: 代码签名配置

**讨论内容**: CI环境中如何使用代码签名证书？

**最终决定**: ✅ **使用GitHub Secrets存储加密证书**
- 将.p12文件转换为base64
- 上传到GitHub Secrets
- workflow中动态导入到临时keychain
- 使用后立即清理

**Secrets配置**:
- `CODESIGN_CERTIFICATE`: base64编码的.p12文件
- `CODESIGN_PASSWORD`: 证书密码

**理由**:
- GitHub Secrets加密安全
- 标准做法，业界最佳实践
- 完全自动化，无需手动干预

---

### 问题5: SHA256校验和

**讨论内容**: 是否需要生成SHA256文件？

**最终决定**: ✅ **生成并上传SHA256校验和文件**
- 文件命名：`Usage4Claude-vX.Y.Z.dmg.sha256`
- 与DMG一起上传到Release

**理由**:
- 业界标准做法
- 验证下载文件完整性
- 防止文件被篡改
- 提升专业度和用户信心

---

### 问题6: 构建配置

**讨论内容**: 使用Release还是Debug配置？

**最终决定**: ✅ **Release配置**

**理由**:
- 生产环境标准
- 优化性能
- 体积更小

---

### 问题7: 并发控制

**讨论内容**: 多个发布同时进行如何处理？

**最终决定**: ✅ **串行执行**
```yaml
concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false
```

**理由**:
- 单人开发，不会并发
- 避免资源冲突
- 确保构建顺序

---

### 问题8: 额外功能

**讨论内容**: 需要哪些额外功能？

**最终决定**:
- ✅ 自动打latest标签（Publish时自动移动）
- ❌ 不需要自动更新CHANGELOG链接（手动维护）
- ❌ 不需要统计信息
- ❌ 不需要其他平台发布（Homebrew等）

---

### 问题9: 模板和标题

**讨论内容**: Release Notes模板语言？标题提示？

**最终决定**:
- ✅ 模板全部使用英文
- ✅ Draft Release标题使用醒目中文提示：
  ```
  v1.1.3 - ❗️❗️❗️请在这里输入你的简短描述❗️❗️❗️
  ```

**理由**:
- 英文模板国际化，面向所有用户
- 中文提示醒目，不会忘记编辑
- emoji在任何语言环境都明显

---

### 问题10: test-release分支策略

**讨论内容**: 测试分支用完后删除还是保留？

**最终决定**: ✅ **保留作为长期测试分支**

**使用方式**:
```bash
git checkout test-release
git merge main          # 同步最新代码
git push origin test-release
```

**理由**:
- 方便下次测试workflow修改
- 保留测试历史
- 长期分支策略清晰

---

### 问题11: 脚本数量和合并

**讨论内容**: 4个脚本是否过度分割？

**最终决定**: ✅ **合并为3个脚本**
- `verify_version.sh` - 版本提取+验证（合并）
- `generate_release_notes.sh` - Release Notes生成
- `cleanup_failed_release.sh` - 失败清理

**理由**:
- 版本提取和验证功能相关，适合合并
- 减少文件数量
- 保持功能模块化

---

### 问题12: Job数量和通知

**讨论内容**: 需要几个Job？是否需要通知Job？

**最终决定**: ✅ **3个Jobs，不需要独立通知Job**
1. **validate** (ubuntu) - 验证和准备
2. **build** (macos) - 构建应用
3. **release** (ubuntu) - 创建发布

**理由**:
- GitHub Actions自动发邮件通知
- 3个Job职责清晰
- 不需要额外通知机制

---

### 问题13: 平台选择策略

**讨论内容**: 为什么使用ubuntu和macOS混合？

**最终决定**: ✅ **混合平台使用**
- validate: ubuntu (便宜、快速)
- build: macOS (必须，用于Xcode编译)
- release: ubuntu (便宜、快速)

**费用对比**:
| 方案 | macOS分钟消耗 | 可用次数/月 |
|-----|-------------|-----------|
| 全macOS | 105分钟 | ~19次 |
| 混合平台 | 80分钟 | ~25次 |

**节省**: 每次节省25分钟macOS费用

**理由**:
- 免费账号macOS额度有限（200分钟/月）
- ubuntu启动快（10秒 vs 40秒）
- 只在必须时使用macOS

---

### 问题14: Draft Release策略

**讨论内容**: 自动发布还是创建草稿？

**最终决定**: ✅ **创建Draft Release，手动Publish**

**workflow行为**:
1. 自动创建Draft Release
2. 上传DMG和SHA256
3. 填充基础Release Notes模板
4. 等待用户手动完善
5. 用户手动点击"Publish Release"

**理由**:
- 保留最后检查和完善的机会
- 可以测试DMG
- 可以优化Release Notes表达
- 符合项目需求（不要完全自动Release）

---

### 问题15: 触发关键字选择

**讨论内容**: 使用什么关键字触发？

**最终决定**: ✅ **`[release]` 或 `[RELEASE]`**

**使用示例**:
```bash
git commit -m "[release] v1.1.3"
# 或
git commit -m "[RELEASE] Update to version 1.1.3"
```

**理由**:
- 方括号格式醒目
- 不会误触发
- 简短易记
- 符合约定式提交规范

---

### 问题16: 脚本位置策略

**讨论内容**: 脚本应该放在哪里？统一还是分离？

**最终决定**: ✅ **分离放置**
```
scripts/               ← 开发者工具（手动使用）
└── build.sh

.github/scripts/       ← CI专用脚本（workflow调用）
├── verify_version.sh
├── generate_release_notes.sh
└── cleanup_failed_release.sh
```

**理由**:
- 职责清晰：开发工具 vs CI工具
- 符合业界标准（React、Vue、TypeScript等）
- build.sh是开发者经常手动运行的工具
- CI脚本只被workflow调用
- 未来扩展性好

---

### 问题17: GitHub免费账号限制

**讨论内容**: 免费账号能否使用macOS？额度够用吗？

**最终决定**: ✅ **可以使用，额度够用**

**额度说明**:
- Linux: 2000分钟/月
- macOS: 相当于200分钟/月（10倍消耗）
- 每次workflow约8分钟macOS
- 可运行约25次/月

**理由**:
- 发布频率不会超过25次/月
- 混合平台策略节省额度
- 完全满足需求

---

## 创建的文件清单

### 文件结构

```
.github/
├── workflows/
│   └── release.yml                      # 主Workflow配置
├── scripts/
│   ├── verify_version.sh                # 版本提取和验证
│   ├── generate_release_notes.sh        # Release Notes生成
│   └── cleanup_failed_release.sh        # 失败清理
└── RELEASE_TEMPLATE.md                  # Release Notes模板

总计: 5个文件
```

### 文件详细说明

#### 1. `.github/workflows/release.yml`
**行数**: 333行  
**功能**: GitHub Actions主Workflow  
**包含内容**:
- 触发条件配置（push、workflow_dispatch）
- 3个Jobs定义（validate、build、release）
- 环境变量配置
- 并发控制
- 错误处理

**触发条件**:
```yaml
on:
  push:
    branches: [main, test-release]
    paths: ['CHANGELOG.md']
  workflow_dispatch:
    inputs:
      dry_run: # 手动触发时可选Dry Run
```

**Jobs流程**:
```
validate (ubuntu, ~30s)
  ↓
build (macos, ~8min)
  ↓
release (ubuntu, ~1min) [仅main分支]
```

---

#### 2. `.github/scripts/verify_version.sh`
**行数**: 154行  
**功能**: 版本号提取和验证  

**支持的命令**:
```bash
# 从CHANGELOG提取版本
./verify_version.sh extract-changelog CHANGELOG.md

# 从Xcode提取版本
./verify_version.sh extract-xcode Usage4Claude.xcodeproj

# 验证版本匹配
./verify_version.sh verify CHANGELOG.md Usage4Claude.xcodeproj
```

**验证规则**:
- CHANGELOG版本格式：`[X.Y.Z]`
- Xcode版本格式：`X.Y.Z`
- 两者必须完全匹配

---

#### 3. `.github/scripts/generate_release_notes.sh`
**行数**: 103行  
**功能**: 生成Release Notes  

**使用方式**:
```bash
./generate_release_notes.sh \
  .github/RELEASE_TEMPLATE.md \
  1.1.3 \
  release_notes.md
```

**功能**:
- 读取模板文件
- 替换 `{{VERSION}}` 为当前版本
- 替换 `{{PREVIOUS_VERSION}}` 为上个版本
- 自动查找上个版本的Git Tag
- 生成完整的Release Notes

---

#### 4. `.github/scripts/cleanup_failed_release.sh`
**行数**: 121行  
**功能**: 清理失败的发布  

**使用方式**:
```bash
./cleanup_failed_release.sh 1.1.3
```

**清理内容**:
- 删除本地Git Tag
- 删除远程Git Tag
- 删除GitHub Release（如果存在）

**使用场景**:
- 构建失败时自动调用
- 手动清理测试Tag

---

#### 5. `.github/RELEASE_TEMPLATE.md`
**行数**: 30行  
**功能**: Release Notes模板  

**包含内容**:
- 英文注释提示（添加描述后删除）
- Installation指南（自动填充版本号）
- Full Changelog链接
- Previous Version链接
- Compare链接

**变量替换**:
- `{{VERSION}}` → 当前版本号
- `{{PREVIOUS_VERSION}}` → 上个版本号

---

### 代码统计

| 类型 | 文件数 | 总行数 |
|-----|-------|--------|
| Workflow | 1 | 333 |
| Shell脚本 | 3 | 378 |
| Markdown模板 | 1 | 30 |
| **总计** | **5** | **741** |

---

## 配置清单

### 前置准备

#### 1. 上传代码签名证书到GitHub Secrets

**步骤**:

```bash
# 1. 在项目根目录执行
cd /Users/iMac/Coding/Projects/Usage4Claude

# 2. 将.p12转换为base64
base64 -i Usage4Claude-CodeSigning.p12 -o cert_base64.txt

# 3. 查看生成的base64内容
cat cert_base64.txt

# 4. 复制全部内容（会很长）
```

**在GitHub网页配置**:

1. 访问项目设置：  
   `https://github.com/f-is-h/Usage4Claude/settings/secrets/actions`

2. 点击 "New repository secret"

3. 添加第一个Secret：
   - Name: `CODESIGN_CERTIFICATE`
   - Value: 粘贴 `cert_base64.txt` 的全部内容

4. 添加第二个Secret：
   - Name: `CODESIGN_PASSWORD`
   - Value: 你的证书密码

5. 清理本地临时文件：
```bash
rm cert_base64.txt
```

**验证配置**:
- 在 Settings → Secrets and variables → Actions
- 应该看到两个Secrets：
  - ✅ `CODESIGN_CERTIFICATE`
  - ✅ `CODESIGN_PASSWORD`

---

#### 2. 确保Git配置正确

```bash
# 检查Git用户信息
git config user.name
git config user.email

# 如果未设置，执行：
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

---

#### 3. 确保文件权限正确

```bash
# 给脚本添加执行权限
chmod +x .github/scripts/*.sh
chmod +x scripts/build.sh

# 验证权限
ls -l .github/scripts/
ls -l scripts/
```

---

### 配置检查清单

在开始测试前，确认以下项目：

- [ ] GitHub Secrets已配置（CODESIGN_CERTIFICATE + CODESIGN_PASSWORD）
- [ ] 脚本文件有执行权限
- [ ] Git用户信息已配置
- [ ] 当前CHANGELOG版本与Xcode版本一致
- [ ] 已创建test-release分支用于测试
- [ ] 已阅读测试步骤

---

## 测试步骤

### 测试阶段概览

```
阶段1: 本地脚本测试 (5分钟)
  ↓
阶段2: test-release分支测试 (15分钟)
  ↓
阶段3: Dry Run完整测试 (20分钟)
  ↓
阶段4: 正式发布 (第一次真实使用)
```

---

### 阶段1: 本地脚本测试

**目的**: 验证脚本逻辑正确性

**时间**: ~5分钟

**步骤**:

```bash
cd /Users/iMac/Coding/Projects/Usage4Claude

# 1. 测试版本提取（从CHANGELOG）
.github/scripts/verify_version.sh extract-changelog CHANGELOG.md
# 预期输出: 1.1.2

# 2. 测试Xcode版本提取
.github/scripts/verify_version.sh extract-xcode Usage4Claude.xcodeproj
# 预期输出: 1.1.2

# 3. 测试版本验证
.github/scripts/verify_version.sh verify CHANGELOG.md Usage4Claude.xcodeproj
# 预期输出: ✅ Version numbers match!

# 4. 测试Release Notes生成
.github/scripts/generate_release_notes.sh \
  .github/RELEASE_TEMPLATE.md \
  1.1.2 \
  test_notes.md

# 5. 检查生成的Release Notes
cat test_notes.md
# 检查版本号是否正确替换

# 6. 清理测试文件
rm test_notes.md
```

**预期结果**:
- ✅ 所有脚本正常执行
- ✅ 版本号提取正确
- ✅ 版本验证通过
- ✅ Release Notes模板正确替换变量

**如果失败**:
- 检查文件路径
- 检查文件权限
- 检查CHANGELOG格式

---

### 阶段2: test-release分支测试

**目的**: 测试workflow的validate和build阶段

**时间**: ~15分钟（主要是等待CI运行）

**步骤**:

```bash
# 1. 创建测试分支（如果不存在）
git checkout -b test-release

# 2. 确保代码是最新的
git merge main

# 3. 提交workflow文件（如果是首次测试）
git add .github/
git commit -m "[release] v1.1.2-test - Testing workflow"
git push origin test-release
```

**在GitHub观察**:

1. 访问 Actions 页面：  
   `https://github.com/f-is-h/Usage4Claude/actions`

2. 查看运行的workflow：  
   - 名称：Build and Release
   - 分支：test-release
   - 触发者：你的用户名

3. 观察各个Job：
   ```
   ✅ validate (ubuntu, ~30秒)
     ├─ Checkout code
     ├─ Check commit message
     ├─ Extract version
     └─ Check if version already released
   
   ✅ build (macos, ~8分钟)
     ├─ Checkout code
     ├─ Setup Xcode
     ├─ Verify version consistency
     ├─ Install dependencies
     ├─ Import code signing certificate
     ├─ Build application
     ├─ Generate SHA256 checksum
     └─ Upload build artifacts
   
   ⏭️  release (ubuntu)
     └─ Skipped (test-release branch)
   ```

4. 下载构建产物：
   - 点击完成的workflow运行
   - 下拉到 "Artifacts" 部分
   - 下载 "release-artifacts"
   - 解压并测试DMG文件

**预期结果**:
- ✅ validate job 成功（约30秒）
- ✅ build job 成功（约8分钟）
- ✅ release job 跳过（test-release分支）
- ✅ 可以下载DMG文件
- ✅ DMG文件可以正常安装和运行

**测试DMG**:
```bash
# 1. 下载并解压artifacts.zip
# 2. 打开DMG文件
open Usage4Claude-v1.1.2.dmg

# 3. 测试安装
# 4. 验证应用可以正常运行
# 5. 验证版本号正确
```

**如果失败**:

检查失败的Job：
```bash
# 如果是validate失败：
- 检查CHANGELOG格式
- 检查commit message是否包含[release]

# 如果是build失败：
- 检查GitHub Secrets是否正确配置
- 检查证书是否有效
- 查看详细日志找出具体错误
```

**测试成功后**:
```bash
# 切换回main分支
git checkout main

# test-release分支保留，将来可继续使用
```

---

### 阶段3: Dry Run完整测试

**目的**: 测试完整的发布流程，包括创建Tag和Release

**时间**: ~20分钟

**警告**: ⚠️ 这会在你的仓库创建测试Tag和Release，需要手动清理

**步骤**:

```bash
# 1. 确保在main分支
git checkout main

# 2. 创建一个测试版本（不要用真实版本号）
# 编辑CHANGELOG.md，在最前面添加测试版本：

## [1.2.0] - 2025-11-02

### Added
- Test release for workflow validation

# 3. 更新Xcode版本号
# 在Xcode中：
# Targets → Usage4Claude → General → Version
# 或 Build Settings → MARKETING_VERSION
# 改为：1.2.0

# 4. 提交
git add CHANGELOG.md Usage4Claude.xcodeproj
git commit -m "[release] v1.2.0 - Dry run test"
git push origin main
```

**立即手动触发Dry Run**:

1. 访问 Actions 页面
2. 点击 "Build and Release" workflow
3. 点击 "Run workflow" 按钮
4. 配置：
   - Branch: `main`
   - Dry run mode: `☑️ true`（勾选）
5. 点击 "Run workflow"

**观察workflow运行**:

```
✅ validate (~30秒)
  └─ 检测到[release]关键字
  └─ 提取版本号：1.2.0
  └─ 设置Dry Run模式

✅ build (~8分钟)
  └─ 验证版本匹配
  └─ 导入证书
  └─ 编译构建
  └─ 生成SHA256
  └─ 上传artifacts

✅ release (~1分钟)
  └─ 创建Tag: test-v1.2.0（注意test-前缀）
  └─ 生成Release Notes
  └─ 创建Draft Release（标题带"DRY RUN TEST"）
  └─ 上传DMG和SHA256
```

**验证结果**:

1. 检查Tags：  
   `https://github.com/f-is-h/Usage4Claude/tags`
   - 应该看到 `test-v1.2.0`

2. 检查Releases：  
   `https://github.com/f-is-h/Usage4Claude/releases`
   - 应该看到Draft Release
   - 标题：`test-v1.2.0 - ⚠️ DRY RUN TEST ⚠️`

3. 下载并测试DMG

**清理测试数据**:

```bash
# 1. 删除测试Tag
git tag -d test-v1.2.0
git push --delete origin test-v1.2.0

# 2. 删除测试Release
# 在GitHub网页上：
# Releases → 找到test-v1.2.0 → Edit → Delete

# 3. 恢复CHANGELOG.md
# 删除测试版本条目：[1.2.0]

# 4. 恢复Xcode版本号
# 改回：1.1.2

# 5. 提交清理
git add CHANGELOG.md Usage4Claude.xcodeproj
git commit -m "chore: revert dry run test"
git push origin main
```

**预期结果**:
- ✅ 所有3个Jobs成功
- ✅ 创建了test-v1.2.0 Tag
- ✅ 创建了Draft Release
- ✅ 上传了DMG和SHA256
- ✅ Release Notes正确生成

**如果失败**:
- 查看失败Job的详细日志
- 检查是否是网络问题
- 检查是否是权限问题
- 根据错误信息调整

---

### 阶段4: 正式发布（第一次真实使用）

**目的**: 进行真正的版本发布

**前提**: 阶段1-3全部测试通过

**步骤**:

```bash
# 1. 准备新版本内容
# 决定新版本号，比如：1.1.3

# 2. 更新CHANGELOG.md
# 在最前面添加新版本：

## [1.1.3] - 2025-11-02

### Fixed
- 修复某个具体的bug

### Added
- 添加某个新功能

# 3. 更新Xcode版本号
# 在Xcode中改为：1.1.3

# 4. 提交
git add CHANGELOG.md Usage4Claude.xcodeproj
git commit -m "[release] v1.1.3"
git push origin main

# 5. 等待workflow完成（约10分钟）
# 你会收到GitHub的邮件通知
```

**编辑Draft Release**:

1. 收到邮件通知后，访问：  
   `https://github.com/f-is-h/Usage4Claude/releases`

2. 找到Draft Release：  
   `v1.1.3 - ❗️❗️❗️请在这里输入你的简短描述❗️❗️❗️`

3. 点击 "Edit" 编辑

4. 修改标题：
   ```
   v1.1.3 - Bug Fix Release
   ```

5. 在最上方添加你的描述：
   ```markdown
   ## 🐛 Bug Fix Release
   
   This release fixes...
   
   ### Fixed
   🔧 User-friendly description...
   
   ### Technical Details
   ...
   
   ### User Impact
   **Before:** ...
   **After:** ...
   
   ---
   
   <!-- 下面是自动生成的内容 -->
   ```

6. 删除模板注释

7. 预览效果

8. 点击 "Publish release"

**验证发布**:

- ✅ Release已发布
- ✅ DMG可下载
- ✅ SHA256可下载
- ✅ Latest标签已移动
- ✅ Tag已创建（v1.1.3）

**首次发布完成！** 🎉

---

### 测试总结

| 阶段 | 目的 | 时间 | 是否必须 |
|-----|------|------|---------|
| 阶段1 | 验证脚本逻辑 | 5分钟 | ✅ 必须 |
| 阶段2 | 测试构建流程 | 15分钟 | ✅ 必须 |
| 阶段3 | 完整流程测试 | 20分钟 | ⚠️ 强烈推荐 |
| 阶段4 | 正式发布 | 15分钟 | ✅ 实际使用 |

**建议顺序执行所有阶段**，确保每个阶段都成功后再进入下一阶段。

---

## 日常使用流程

### 标准发布流程

经过测试验证后，以后每次发布只需要以下步骤：

```bash
# ============================================
# 步骤1: 准备发布（本地，5分钟）
# ============================================

# 1.1 更新CHANGELOG.md
vim CHANGELOG.md
# 添加新版本条目，格式：
## [X.Y.Z] - YYYY-MM-DD

### Added
- 新功能描述

### Changed
- 变更描述

### Fixed
- Bug修复描述

# 1.2 更新Xcode版本号
# 打开Xcode
# Targets → Usage4Claude → General → Version
# 或 Build Settings → MARKETING_VERSION
# 改为：X.Y.Z（与CHANGELOG一致）

# 1.3 提交并推送
git add CHANGELOG.md Usage4Claude.xcodeproj
git commit -m "[release] vX.Y.Z"
git push origin main

# ============================================
# 步骤2: 等待CI完成（自动，~10分钟）
# ============================================

# 你会收到GitHub邮件通知：
# - Workflow开始运行
# - Workflow完成（成功/失败）

# 可选：在Actions页面监控进度
# https://github.com/f-is-h/Usage4Claude/actions

# ============================================
# 步骤3: 完善Release Notes（网页，2分钟）
# ============================================

# 3.1 访问Releases页面
# https://github.com/f-is-h/Usage4Claude/releases

# 3.2 找到Draft Release（标题带❗️提示）

# 3.3 点击Edit编辑

# 3.4 修改标题
# 从：vX.Y.Z - ❗️❗️❗️请在这里输入你的简短描述❗️❗️❗️
# 改为：vX.Y.Z - Bug Fix Release（或其他合适的描述）

# 3.5 在最上方添加用户友好的描述
# 使用emoji、格式化、Before/After对比等

# 3.6 删除模板注释

# 3.7 预览效果

# 3.8 点击 "Publish release"

# ============================================
# 完成！🎉
# ============================================

# 验证：
# - ✅ Release已发布
# - ✅ 用户可以下载DMG
# - ✅ Latest标签已更新
# - ✅ Tag已创建
```

---

### 快速参考

**触发发布**:
```bash
git commit -m "[release] v1.1.4"
git push origin main
```

**触发条件**:
- ✅ Commit message包含 `[release]` 或 `[RELEASE]`
- ✅ 修改了 CHANGELOG.md
- ✅ 推送到 main 分支

**不触发**:
- ❌ 没有 `[release]` 关键字
- ❌ 没有修改 CHANGELOG.md
- ❌ 推送到其他分支（test-release除外）

---

### 关键注意事项

1. **版本号一致性**  
   CHANGELOG和Xcode的版本号必须完全一致，否则构建会失败

2. **Commit Message格式**  
   必须包含 `[release]` 或 `[RELEASE]` 关键字

3. **Draft Release编辑**  
   不要忘记编辑标题和添加描述，否则用户会看到❗️提示

4. **测试DMG**  
   发布前建议下载Draft Release的DMG测试一下

5. **CHANGELOG格式**  
   保持标准格式：`## [X.Y.Z] - YYYY-MM-DD`

---

## 故障排除

### 常见问题和解决方案

#### 问题1: Workflow没有触发

**症状**: 推送代码后，Actions页面没有新的运行记录

**可能原因**:
1. Commit message没有包含 `[release]` 关键字
2. 没有修改 CHANGELOG.md
3. 推送到了错误的分支

**解决方案**:
```bash
# 检查commit message
git log -1

# 检查修改的文件
git show --name-only

# 如果需要重新触发
git commit --amend -m "[release] v1.1.4"
git push -f origin main
```

---

#### 问题2: 版本验证失败

**症状**: build job失败，提示版本号不匹配

**错误信息**:
```
❌ Version mismatch!
CHANGELOG: 1.1.4
Xcode: 1.1.3
```

**解决方案**:
```bash
# 1. 在Xcode中更新版本号
# Targets → Build Settings → MARKETING_VERSION

# 2. 提交修复
git add Usage4Claude.xcodeproj
git commit -m "[release] v1.1.4 - Fix version number"
git push origin main

# 3. 等待workflow重新运行
```

---

#### 问题3: 证书导入失败

**症状**: build job失败，证书相关错误

**错误信息**:
```
Error: Failed to import certificate
security: SecKeychainItemImport: The specified item already exists in the keychain
```

**可能原因**:
1. GitHub Secrets配置错误
2. 证书密码错误
3. 证书文件损坏

**解决方案**:
```bash
# 1. 重新生成base64证书
cd /Users/iMac/Coding/Projects/Usage4Claude
base64 -i Usage4Claude-CodeSigning.p12 -o cert_new.txt

# 2. 更新GitHub Secrets
# Settings → Secrets → Edit CODESIGN_CERTIFICATE
# 粘贴新的base64内容

# 3. 确认证书密码正确
# Settings → Secrets → Edit CODESIGN_PASSWORD

# 4. 重新运行workflow
# Actions → 失败的运行 → Re-run jobs
```

---

#### 问题4: 构建超时

**症状**: build job运行超过15分钟后失败

**错误信息**:
```
Error: The job running on runner has exceeded the maximum execution time of 15 minutes
```

**可能原因**:
1. 网络问题（下载依赖慢）
2. 编译卡住
3. macOS runner资源不足

**解决方案**:
```bash
# 1. 重新运行workflow
# Actions → 失败的运行 → Re-run failed jobs

# 2. 如果持续失败，增加超时时间
# 编辑 .github/workflows/release.yml
timeout-minutes: 20  # 从15改为20

git add .github/workflows/release.yml
git commit -m "ci: increase timeout"
git push origin main
```

---

#### 问题5: DMG创建失败

**症状**: build job在"Build application"步骤失败

**错误信息**:
```
❌ 创建 DMG 失败
```

**可能原因**:
1. create-dmg安装失败
2. 图标文件不存在
3. 磁盘空间不足

**解决方案**:
```bash
# 检查本地构建是否正常
./scripts/build.sh

# 如果本地成功但CI失败：
# 1. 检查图标路径是否正确
# 2. 检查build.sh中的路径是否是绝对路径
# 3. 查看详细日志找出具体错误
```

---

#### 问题6: Tag已存在

**症状**: release job失败，提示Tag已存在

**错误信息**:
```
❌ Tag v1.1.4 already exists!
```

**可能原因**:
1. 之前的发布失败但Tag已创建
2. 版本号没有更新

**解决方案**:
```bash
# 方案A: 删除旧Tag，重新发布
git tag -d v1.1.4
git push --delete origin v1.1.4

# 然后重新推送代码
git commit --amend -m "[release] v1.1.4"
git push -f origin main

# 方案B: 使用新版本号
# 更新CHANGELOG.md和Xcode版本号为1.1.5
```

---

#### 问题7: 上传artifacts失败

**症状**: build job最后一步失败

**错误信息**:
```
Error: Unable to upload artifact
```

**可能原因**:
1. 文件路径错误
2. 文件不存在
3. 网络问题

**解决方案**:
```bash
# 1. 检查构建产物路径是否正确
# 查看build job日志，确认DMG文件位置

# 2. 检查workflow中的路径配置
# .github/workflows/release.yml
# 确保路径与build.sh输出一致

# 3. 重新运行job
# Actions → Re-run failed jobs
```

---

#### 问题8: Release创建失败

**症状**: release job失败

**错误信息**:
```
Error: Resource not accessible by integration
```

**可能原因**:
1. GitHub token权限不足
2. 仓库设置问题

**解决方案**:
```bash
# 检查仓库权限
# Settings → Actions → General
# Workflow permissions → 选择 "Read and write permissions"
# 勾选 "Allow GitHub Actions to create and approve pull requests"
```

---

#### 问题9: macOS额度用完

**症状**: workflow排队等待，迟迟不开始

**错误信息**:
```
Waiting for a runner to pick up this job...
```

**可能原因**:
当月macOS额度已用完

**解决方案**:
```bash
# 方案A: 等待下月额度重置

# 方案B: 临时使用本地构建
./scripts/build.sh

# 手动上传DMG到Release
# 1. 在GitHub创建Release
# 2. 手动上传DMG和SHA256

# 方案C: 升级到付费计划（如果需要）
```

---

#### 问题10: Dry Run测试无法清理

**症状**: 删除test-tag后仍有残留

**解决方案**:
```bash
# 1. 删除本地tag
git tag -d test-v1.2.0

# 2. 删除远程tag
git push --delete origin test-v1.2.0

# 3. 删除GitHub Release
# 访问: https://github.com/f-is-h/Usage4Claude/releases
# 找到test-v1.2.0
# Edit → Delete

# 4. 如果还有缓存，强制刷新
git fetch --prune
```

---

### 获取帮助

**查看日志**:
1. Actions页面 → 点击运行记录
2. 点击失败的Job
3. 展开失败的步骤
4. 查看详细错误信息

**常用调试命令**:
```bash
# 查看最近的commit
git log -1

# 查看本地tags
git tag -l

# 查看远程tags
git ls-remote --tags origin

# 测试脚本
.github/scripts/verify_version.sh verify CHANGELOG.md Usage4Claude.xcodeproj
```

**联系支持**:
- GitHub Actions文档: https://docs.github.com/en/actions
- GitHub Actions状态: https://www.githubstatus.com/

---

## 附录

### A. Workflow配置参考

**环境变量**:
```yaml
env:
  PROJECT_NAME: Usage4Claude
  XCODE_PROJECT: Usage4Claude.xcodeproj
  BUILD_CONFIG: Release
```

**超时配置**:
```yaml
timeout-minutes: 15  # build job
timeout-minutes: 10  # release job
timeout-minutes: 5   # validate job
```

**并发控制**:
```yaml
concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false
```

---

### B. 脚本命令参考

**verify_version.sh**:
```bash
# 提取CHANGELOG版本
./verify_version.sh extract-changelog CHANGELOG.md

# 提取Xcode版本
./verify_version.sh extract-xcode Usage4Claude.xcodeproj

# 验证版本匹配
./verify_version.sh verify CHANGELOG.md Usage4Claude.xcodeproj
```

**generate_release_notes.sh**:
```bash
# 生成Release Notes
./generate_release_notes.sh <template> <version> <output>

# 示例
./generate_release_notes.sh \
  .github/RELEASE_TEMPLATE.md \
  1.1.4 \
  release_notes.md
```

**cleanup_failed_release.sh**:
```bash
# 清理失败的发布
./cleanup_failed_release.sh <version>

# 示例
./cleanup_failed_release.sh 1.1.4
```

---

### C. Git命令参考

**Tag管理**:
```bash
# 查看所有tags
git tag -l

# 创建tag
git tag -a v1.1.4 -m "Release v1.1.4"

# 推送tag
git push origin v1.1.4

# 删除本地tag
git tag -d v1.1.4

# 删除远程tag
git push --delete origin v1.1.4
```

**分支管理**:
```bash
# 创建测试分支
git checkout -b test-release

# 切换分支
git checkout main

# 同步测试分支
git checkout test-release
git merge main
git push origin test-release
```

---

### D. 版本号规范

**语义化版本 (Semantic Versioning)**:
```
格式: MAJOR.MINOR.PATCH

MAJOR: 不兼容的API变更
MINOR: 向后兼容的功能新增
PATCH: 向后兼容的bug修复

示例:
1.0.0 → 首次发布
1.1.0 → 新增功能
1.1.1 → Bug修复
2.0.0 → 重大更新
```

**Usage4Claude的版本策略**:
- 1.x.x: 正式版本
- Bug修复: +0.0.1
- 新功能: +0.1.0
- 重大更新: +1.0.0

---

### E. CHANGELOG格式规范

**标准格式**:
```markdown
# Changelog

## [Unreleased]
### Added
- 未发布的新功能

## [1.1.4] - 2025-11-02

### Added
- 新增功能描述

### Changed
- 变更描述

### Deprecated
- 即将废弃的功能

### Removed
- 已移除的功能

### Fixed
- Bug修复描述

### Security
- 安全问题修复
```

**分类说明**:
- **Added**: 新功能
- **Changed**: 已有功能的变更
- **Deprecated**: 即将移除的功能
- **Removed**: 已移除的功能
- **Fixed**: Bug修复
- **Security**: 安全修复

---

### F. Release Notes最佳实践

**好的Release Notes示例**:

```markdown
## 🐛 Bug Fix Release

This release fixes critical issues with error handling and improves user experience.

### Fixed
🔧 **Error Message Localization**: All error messages now display in your selected language
🔧 **Network Error Handling**: Better error messages for network failures
🔧 **Authentication Errors**: Clear guidance when credentials are incorrect

### Technical Details
- Added `networkError` and `decodingError` to error handling system
- Updated all 4 language files with new error translations
- Enhanced debug logging for troubleshooting

### User Impact
**Before:**
- Confusing system errors in English only
- "The data couldn't be read because it is missing"

**After:**
- Clear, localized error messages
- "Failed to parse response. Please check your credentials."

---

### 📦 Installation
...
```

**关键要素**:
- ✅ 清晰的标题（带emoji）
- ✅ 简短的总结
- ✅ 面向用户的描述
- ✅ Before/After对比
- ✅ 技术细节（可选）

---

## 总结

### 实现成果

通过本次工作，我们完成了：

1. **5个文件的创建**
   - 1个主Workflow配置
   - 3个Shell脚本
   - 1个Release Notes模板

2. **3个阶段的自动化**
   - 验证阶段（validate）
   - 构建阶段（build）
   - 发布阶段（release）

3. **完整的测试方案**
   - 本地脚本测试
   - 分支隔离测试
   - Dry Run完整测试
   - 正式发布流程

4. **详细的文档**
   - 决策记录
   - 配置指南
   - 使用说明
   - 故障排除

### 核心特性

- ✅ **关键字触发**: `[release]` commit message
- ✅ **版本验证**: CHANGELOG ↔ Xcode
- ✅ **自动构建**: 编译、签名、打包
- ✅ **SHA256生成**: 文件完整性验证
- ✅ **Draft Release**: 保留手动完善的空间
- ✅ **失败清理**: 自动删除失败的Tag
- ✅ **成本优化**: 混合平台，节省macOS额度

### 使用便利性

**对于开发者**:
- 只需一次commit + push
- 无需手动创建Tag
- 无需手动上传文件
- 保留最后检查权限

**工作量对比**:

| 步骤 | 手动流程 | 自动化流程 |
|-----|---------|-----------|
| 更新版本号 | ✅ 必须 | ✅ 必须 |
| 编译构建 | ✅ 5-10分钟 | ⏱️ 自动（8分钟）|
| 创建Tag | ✅ 手动 | ⏱️ 自动 |
| 生成SHA256 | ✅ 手动 | ⏱️ 自动 |
| 创建Release | ✅ 手动 | ⏱️ 自动 |
| 上传文件 | ✅ 手动 | ⏱️ 自动 |
| 编写Notes | ✅ 完全手写 | ⚡ 模板+手动 |
| **总时间** | **~20-30分钟** | **~5分钟人工** |

### 安全性

- ✅ 证书加密存储（GitHub Secrets）
- ✅ 临时keychain使用后删除
- ✅ 不在日志中暴露敏感信息
- ✅ 代码签名保证软件完整性
- ✅ SHA256验证下载文件

### 可维护性

- ✅ 清晰的目录结构
- ✅ 模块化脚本设计
- ✅ 详细的注释和文档
- ✅ 标准化的命名规范
- ✅ 完整的错误处理

### 扩展性

未来可以轻松添加：
- 更多测试阶段
- 其他平台发布（Homebrew）
- 通知集成（Slack/Discord）
- 自动化更多步骤

---

## 下一步行动

### 立即执行

1. **上传证书到GitHub Secrets** (5分钟)
2. **本地测试脚本** (5分钟)
3. **test-release分支测试** (15分钟)
4. **Dry Run测试** (20分钟)

### 准备就绪后

5. **第一次正式发布** (使用v1.1.3)
6. **验证整个流程**
7. **记录任何问题**

### 持续优化

- 根据实际使用调整配置
- 优化Release Notes模板
- 完善错误处理
- 更新文档

---

**文档版本**: 1.0  
**最后更新**: 2025-11-02  
**状态**: ✅ 已完成

---

*祝发布顺利！🚀*
