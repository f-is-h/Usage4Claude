# Usage4Claude 产品网站开发指南（精简版）

> 本指南用于指导Claude Code开发Usage4Claude产品网站
> 适用于Cloudflare Pages静态部署

---

## 🎯 关键技术决策（2025-12-18）

### 多语言实现方案：混合方案 ✅

**决策背景**：
- 经过深入分析 SEO、性能、维护成本和扩展性
- 平衡了单页面方案和多页面方案的优劣

**最终方案**：
```
主页（index.html）：多页面方案
├── index.html          # 英文主页（主版本）
├── index.zh-cn.html    # 简体中文
├── index.ja.html       # 日语
└── index.zh-tw.html    # 繁体中文

法律页面：单页面 + JS 切换
├── legal.html          # 特商法（日英双语切换）
└── privacy.html        # 隐私政策（4语言切换）
```

**方案优势**：
- ✅ **主页 SEO 完美**：每种语言独立 URL，搜索引擎直接索引
- ✅ **主页性能最优**：零 JS 依赖，加载速度极快
- ✅ **法律页面灵活**：单页面切换，用户体验好，且无需 SEO
- ✅ **维护成本可控**：4 个主页文件 + AI 辅助同步，完全可管理
- ✅ **扩展性充足**：支持 4-10 种语言，满足实际需求

### 主版本语言：英文（index.html）

**决策说明**：
- 主页面 `index.html` 使用**英文**作为内容语言
- 理由：英文是国际通用语言，覆盖最广泛的用户群体
- 其他语言版本：
  - `index.zh-cn.html` - 简体中文
  - `index.ja.html` - 日语
  - `index.zh-tw.html` - 繁体中文

### 代码规范

**注释策略**：
- ✅ **无需注释**：代码逻辑清晰，LLM 易于理解
- ✅ **特殊情况**：仅在必要时添加**英文注释**
- ✅ **文档完善**：通过 README 和本指南提供上下文

### 开发流程

**分阶段开发**：
1. **第一阶段**：仅开发英文主页（`index.html`）
2. **迭代调整**：完善所有功能、设计、响应式等
3. **最终同步**：所有调整完成后，一次性同步到其他 3 个语言版本

**同步策略**：
- 以 `index.html`（英文）为主版本
- 使用 Claude Code 批量同步修改到其他语言版本
- 使用 Git diff 检查版本一致性

---

## 📋 项目概述

### 项目目标
为Usage4Claude macOS应用创建产品展示网站：
- 向用户介绍产品功能
- 提供下载和文档
- 满足Stripe审核的法律合规要求（特商法、隐私政策）

### 核心要求
- ✅ 现代轻量、快速加载
- ✅ 完全免费（无付费组件）
- ✅ 易于AI开发和维护
- ✅ 符合日本法律和Stripe要求

---

## 🛠 技术栈

```
HTML5                    - 页面结构
Tailwind CSS (CDN)       - 样式框架
Alpine.js (可选)         - 轻量交互
纯CSS动画                - 视觉效果
Cloudflare Pages Functions - 地址替换（边缘计算）
```

**为什么？** 零构建、零依赖、直接部署、AI最擅长

---

## 📁 项目结构

```
Usage4Claude/
└── website/
    ├── functions/              # Cloudflare Pages Functions
    │   ├── _middleware.js      # 地址替换中间件
    │   └── README.md
    │
    ├── index.html              # 英文主页（主版本）
    ├── index.zh-cn.html        # 简体中文主页
    ├── index.ja.html           # 日语主页
    ├── index.zh-tw.html        # 繁体中文主页
    │
    ├── legal.html              # 特商法表記（单页面，日英切换）
    ├── privacy.html            # 隐私政策（单页面，4语言切换）
    │
    ├── css/
    │   └── custom.css          # 自定义样式
    │
    ├── js/
    │   ├── i18n.js             # 法律页面多语言切换
    │   ├── translations.js     # 法律页面翻译数据
    │   └── main.js             # 基础交互脚本
    │
    ├── images/
    │   ├── icon.png            # 从docs/images复制
    │   ├── og-image.png        # 社交分享图片
    │   └── screenshots/        # 功能截图
    │
    ├── favicon.ico
    ├── robots.txt
    ├── README.md               # 网站说明
    └── .gitignore
```

---

## 🎨 设计指南

### 配色方案（Claude官方品牌色）

```css
/* 主色调 */
--claude-orange: #CC785C;      /* CTA按钮、强调色 */
--claude-cream: #F5F3ED;       /* 背景色 */
--claude-dark: #1F1F1F;        /* 标题 */
--claude-text: #2D2D2D;        /* 正文 */

/* Usage4Claude状态色 */
--safe-green: #34C759;         /* 5小时安全 */
--warn-orange: #FF9500;        /* 警告 */
--danger-red: #FF3B30;         /* 危险 */
--safe-cyan: #5AC8FA;          /* 7天安全 */
--safe-purple: #5E5CE6;        /* 7天警告 */
```

### 设计原则
- **参考苹果产品页面**：简洁、优雅、大留白
- **字体**：系统原生字体栈（-apple-system等）
- **响应式**：移动优先，断点：640px / 768px / 1024px / 1280px
- **间距**：使用Tailwind spacing（4px基准），模块间距80-120px

---

## 📄 页面内容规划

### 首页（index.html）

**必需模块（按顺序）**：
1. **Header导航** - Logo + 导航链接（功能/下载/GitHub）
2. **Hero区** - 主标题 + 副标题 + CTA按钮 + 应用截图
3. **核心功能** - 3-6个功能点（图标 + 标题 + 描述）
4. **产品截图** - 菜单栏样式、详情窗口、设置界面
5. **下载区** - 系统要求 + 下载按钮 + GitHub Star
6. **Footer** - 版权 + 链接（GitHub/Issues/法律页面）

**功能点建议**（基于README提炼）：
- 实时监控 - 菜单栏显示使用配额
- 跨平台 - Web/CLI/Desktop/Mobile通用
- 智能刷新 - 自适应刷新频率
- 多语言 - 英日中繁四语言
- 安全隐私 - 本地存储+Keychain加密
- 开源透明 - MIT License

### 特商法页面（legal.html）

**页面配置**：
```html
<meta name="robots" content="noindex, nofollow">
```

**必需信息项（日英双语）**：
1. 标题：特定商取引法に基づく表記
2. 事業者名（Business Name）
3. 所在地（Address）：`[ADDRESS_PLACEHOLDER]` ← 部署时替换
4. 連絡先（Email）
5. 商品内容：开源软件的自愿捐赠支持
6. 価格：任意金额，软件免费
7. 支払方法：GitHub Sponsors (via Stripe)
8. 返品：捐赠性质，一般不退款
9. ライセンス：MIT License

**样式**：小字号（text-sm）+ 低对比度，信息完整但不显眼

### 隐私政策页面（privacy.html）

**核心内容**：
- 明确说明：不收集任何用户数据
- 所有数据仅存本地Mac
- Session Key通过Keychain加密
- 无追踪、无分析
- 代码开源可审计

---

## ⚠️ Cloudflare Pages 关键注意

### Clean URLs
Cloudflare 自动去掉 `.html` 扩展名（`/legal.html` → `/legal`，返回 308 重定向）

**代码要求**：
```javascript
// ❌ 错误 - 导致重定向循环
window.location.href = 'index.zh-cn.html';

// ✅ 正确
window.location.href = '/index.zh-cn';
```

### 语言检测必须检查当前页面
```javascript
const targetPage = langMap[userLang];
const currentPath = window.location.pathname;
// 避免重复跳转当前页面
if (targetPage && currentPath !== targetPage && currentPath + '.html' !== targetPage) {
  window.location.href = targetPage;
}
```

### Pages Functions (Middleware)
- 用于动态替换敏感信息
- 不要复制原始 response headers
- 只设置 `Content-Type` header

---

## 🚀 开发阶段（10步）

### ⚠️ 核心原则
**分阶段开发，每阶段完成后手动验证再继续！**

每个阶段：
1. 完成任务
2. 在浏览器测试（`python3 -m http.server 8000`）
3. 确认无误后继续

---

### 阶段1：项目初始化

**任务**：
- 创建website/目录和基础结构
- 创建index.html（基本框架 + Tailwind CDN）
- 从docs/images/复制图标和截图
- 创建.gitignore

**验证**：
- [ ] 页面在浏览器正常显示
- [ ] Tailwind样式生效
- [ ] 图片正常加载

---

### 阶段2：Hero区

**任务**：
- 创建导航栏
- 设计Hero区（主副标题 + CTA + 应用截图）
- 实现米色到白色渐变背景
- CTA按钮使用Claude橙色

**验证**：
- [ ] Hero区视觉效果大气（至少80vh）
- [ ] 响应式布局正常
- [ ] 与Claude品牌感觉一致

---

### 阶段3：功能展示

**任务**：
- 网格布局展示3-6个核心功能
- 每个功能：emoji/图标 + 标题 + 简短描述
- 简单的hover效果

**验证**：
- [ ] 功能点清晰易懂
- [ ] 移动端布局合理
- [ ] 整体风格协调

---

### 阶段4：截图与下载

**任务**：
- 添加产品截图展示区
- 使用README中的现有截图
- 设计下载CTA区（系统要求 + 下载按钮）
- 链接到GitHub Releases

**验证**：
- [ ] 截图清晰可见
- [ ] 下载链接正确
- [ ] 图片加载速度合理

---

### 阶段5：页脚与导航

**任务**：
- 创建页脚（版权 + GitHub链接 + 法律链接）
- 完善导航栏链接
- 实现平滑滚动（锚点跳转）

**验证**：
- [ ] 所有链接正确
- [ ] 锚点跳转平滑
- [ ] 页脚信息完整

---

### 阶段6：特商法页面

**任务**：
- 创建legal.html
- 添加noindex meta标签
- 日英双语版本
- 填写所有必需项（地址用`[ADDRESS_PLACEHOLDER]`）
- 使用小字号和低对比度

**验证**：
- [ ] 所有必需信息完整
- [ ] 日英内容一致
- [ ] 页面设置noindex
- [ ] 从首页可访问

---

### 阶段7：隐私政策

**任务**：
- 创建privacy.html
- 说明数据处理方式
- 强调本地存储和开源透明

**验证**：
- [ ] 内容清晰无歧义
- [ ] 与README隐私说明一致
- [ ] 从首页和legal可访问

---

### 阶段8：响应式优化

**任务**：
- 测试所有设备尺寸（375px / 768px / 1280px+）
- 优化移动端布局
- 压缩图片
- 添加必要的过渡动画

**验证**：
- [ ] 移动端完美显示
- [ ] 无横向滚动
- [ ] 触摸区域≥44px
- [ ] 加载速度<3秒

---

### 阶段9：SEO优化

**任务**：
- 优化title和meta description
- 添加Open Graph标签
- 设置favicon
- 创建robots.txt

**验证**：
- [ ] Meta标签完整
- [ ] 社交分享预览正常
- [ ] Favicon显示

---

### 阶段10：最终测试

**基础测试**：
- [ ] 所有链接正常工作
- [ ] 所有图片正常加载
- [ ] 响应式布局无问题
- [ ] legal.html设置noindex
- [ ] 无控制台错误
- [ ] Lighthouse分数>90

**跨浏览器测试**（关键）：
- [ ] Chrome（英语）- 显示英文
- [ ] Chrome（中文）- 跳转中文，无无限刷新
- [ ] Safari（中文）- 跳转中文，无无限刷新
- [ ] Edge（中文）- 跳转中文，无无限刷新
- [ ] 隐私模式正常
- [ ] 清除 localStorage 后语言检测仍正常

**Pages Functions**（部署后测试）：
- [ ] Legal 页面地址已替换
- [ ] Real-time Logs 显示 Functions 执行
- [ ] Network 面板无 308 循环

---

## 📦 Cloudflare部署

### 构建配置
```yaml
Build command: (留空)
Build output directory: /
Root directory: website
```

### 部署步骤
1. **连接仓库**：Cloudflare Dashboard → Pages → 连接GitHub仓库
2. **选择目录**：选择website作为根目录
3. **替换地址**：在Cloudflare编辑器中将`[ADDRESS_PLACEHOLDER]`替换为真实地址
4. **测试**：访问生成的.pages.dev URL验证

### 自定义域名（可选）
- 在Pages设置中添加自定义域名
- 配置DNS记录

---

## ✅ 最终检查清单

### 设计
- [ ] 整体风格现代、专业
- [ ] 配色协调（Claude品牌色）
- [ ] 间距合理，留白充足

### 内容
- [ ] 功能描述准确
- [ ] 与README一致
- [ ] 无拼写/语法错误

### 技术
- [ ] 所有页面可访问
- [ ] 图片已优化
- [ ] 响应式完美
- [ ] 性能优异

### 合规
- [ ] 特商法内容完整
- [ ] 地址信息正确（部署时）
- [ ] 隐私政策清晰
- [ ] legal页面noindex

---

## 💡 关键提醒

### 对Claude Code
1. **分阶段执行** - 不要一次完成所有
2. **保持简洁** - 避免过度工程
3. **注重细节** - 间距对齐要精确
4. **测试为先** - 每次改动都验证

### 地址占位符
```html
<!-- 源码中 -->
<p>[ADDRESS_PLACEHOLDER]</p>

<!-- 部署时提醒用户手工替换为形如以下的真实地址 -->
<p>〒100-8111 日本东京都千代田区千代田 1-1</p>
```

### 本地预览
```bash
cd website
python3 -m http.server 8000
# 访问 http://localhost:8000
```

---

## 🎯 成功标准

完成后网站应：
- ✅ 看起来专业成熟
- ✅ 清晰传达产品价值
- ✅ 提供完整信息
- ✅ 满足Stripe审核要求
- ✅ 性能优异
- ✅ 易于维护

---

## 📝 开发完成后

提供：
1. 完整的网站文件（website/目录）
2. 部署说明文档（website/README.md）
3. 测试报告

---

**记住核心原则：分阶段开发，每阶段验证，保持简洁，注重细节！**

🚀 开始开发吧！

---

*Usage4Claude项目 | 2025年12月18日*
