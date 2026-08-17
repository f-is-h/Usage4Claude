# Cloudflare Pages 部署指南

> ⚠️ **域名迁移待定**：本文档中的 `usagepacecc.pages.dev` 尚未生效——Cloudflare Pages
> 项目本身的改名被推迟到 Phase 08。在 Phase 08 完成之前，该域名会 404；仍在线的
> `usage4claude.pages.dev` 也不再被任何文档引用。这是已知且可接受的过渡状态（网站尚未
> 对外推广，无外部用户）。

将 UsagePaceCC 网站部署到 Cloudflare Pages 的完整步骤。

## 准备工作

- ✅ Cloudflare 账号
- ✅ GitHub 仓库：`quangyendn/UsagePaceCC`
- ✅ 域名：`fi5h.xyz`（已注册）
- ✅ 目标网址：`u4c.fi5h.xyz`

---

## 步骤 1：连接 GitHub 仓库

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 左侧菜单选择 **Workers & Pages**
3. 点击 **Create application** → **Pages** → **Connect to Git**
4. 授权 Cloudflare 访问你的 GitHub 账号
5. 选择仓库：**quangyendn/UsagePaceCC**

---

## 步骤 2：配置构建设置

在 **Set up builds and deployments** 页面填写：

| 配置项 | 值 |
|--------|-----|
| **Project name** | `usage4claude`（或其他名称）|
| **Production branch** | `main` |
| **Build command** | （留空）|
| **Build output directory** | `/` |
| **Root directory** | `website` |

**环境变量（Environment Variables）**：

| Variable name | Value (示例) | 说明 |
|--------------|-------------|------|
| `REAL_NAME` | `山田 太郎` | 真实姓名 |
| `REAL_EMAIL` | `contact@example.com` | 联系邮箱 |
| `REAL_ADDRESS` | `〒100-0001 東京都千代田区千代田 1-1` | 物理地址 |

点击 **Save and Deploy**

**关于 Pages Functions**：
- 项目使用 `website/functions/_middleware.js` 动态替换敏感信息占位符
- Cloudflare 会自动检测并部署 Functions，无需额外配置
- 修改后需重新部署才能生效

---

## 步骤 3：添加自定义域名

### 3.1 添加域名到 Cloudflare（如果还没有）

1. 在 Cloudflare 主页点击 **Add a site**
2. 输入域名：`fi5h.xyz`
3. 选择免费计划
4. 按照指引更新域名的 DNS 服务器到 Cloudflare 提供的服务器
5. 等待域名激活（通常 5-60 分钟）

### 3.2 为 Pages 项目添加自定义域名

1. 进入 Pages 项目 → **Custom domains** 标签
2. 点击 **Set up a custom domain**
3. 输入：`u4c.fi5h.xyz`
4. 点击 **Continue**
5. Cloudflare 会自动添加必要的 DNS 记录（CNAME）
6. 等待 SSL 证书生成（通常 1-5 分钟）

---

## 步骤 4：验证部署

访问以下网址确认部署成功：

- ✅ **临时域名**：`https://usagepacecc.pages.dev`（或你的项目名）
- ✅ **自定义域名**：`https://u4c.fi5h.xyz`

测试检查清单：

- [ ] 首页正常显示，样式正确
- [ ] 4 种语言切换正常（EN / 日本語 / 简中 / 繁中）
- [ ] 所有图片正常加载
- [ ] 点击下载按钮跳转到 GitHub Releases
- [ ] Legal 页面日英双语切换正常
- [ ] Privacy 页面 4 语言切换正常
- [ ] 移动端显示正常
- [ ] HTTPS 正常工作

---

## 步骤 5：更新网站文件中的域名

部署成功后，需要更新以下文件中的域名引用：

### 5.1 更新所有 HTML 文件

将所有 `https://usagepacecc.pages.dev` 替换为 `https://u4c.fi5h.xyz`

**需要更新的文件**：
- `website/index.html`
- `website/index.ja.html`
- `website/index.zh-cn.html`
- `website/index.zh-tw.html`
- `website/privacy.html`
- `website/legal.html`

**需要替换的位置**：
- `<link rel="canonical">`
- `<link rel="alternate" hreflang="...">`
- `<meta property="og:url">`
- `<meta property="og:image">`
- `<meta name="twitter:image">`

### 5.2 更新 robots.txt

编辑 `website/robots.txt`：

```
User-agent: *
Allow: /
Disallow: /legal.html

Sitemap: https://u4c.fi5h.xyz/sitemap.xml
```

### 5.3 提交更新

```bash
git add website/
git commit -m "update: change domain to u4c.fi5h.xyz"
git push origin main
```

Cloudflare Pages 会自动重新部署。

---

## 步骤 6：配置 Sitemap（可选）

创建 `website/sitemap.xml`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml">

  <url>
    <loc>https://u4c.fi5h.xyz/</loc>
    <xhtml:link rel="alternate" hreflang="en" href="https://u4c.fi5h.xyz/"/>
    <xhtml:link rel="alternate" hreflang="ja" href="https://u4c.fi5h.xyz/index.ja.html"/>
    <xhtml:link rel="alternate" hreflang="zh-CN" href="https://u4c.fi5h.xyz/index.zh-cn.html"/>
    <xhtml:link rel="alternate" hreflang="zh-TW" href="https://u4c.fi5h.xyz/index.zh-tw.html"/>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>

  <url>
    <loc>https://u4c.fi5h.xyz/index.ja.html</loc>
    <changefreq>weekly</changefreq>
    <priority>0.9</priority>
  </url>

  <url>
    <loc>https://u4c.fi5h.xyz/index.zh-cn.html</loc>
    <changefreq>weekly</changefreq>
    <priority>0.9</priority>
  </url>

  <url>
    <loc>https://u4c.fi5h.xyz/index.zh-tw.html</loc>
    <changefreq>weekly</changefreq>
    <priority>0.9</priority>
  </url>

  <url>
    <loc>https://u4c.fi5h.xyz/privacy.html</loc>
    <changefreq>monthly</changefreq>
    <priority>0.5</priority>
  </url>

</urlset>
```

---

## 常见问题

### Q: 部署后样式没有加载？
**A**: 检查浏览器控制台错误，确认 Tailwind CDN 正常加载。可以尝试清除浏览器缓存。

### Q: 自定义域名显示 "Too Many Redirects"？
**A**: 检查 Cloudflare SSL/TLS 设置：
1. 进入域名的 **SSL/TLS** 设置
2. 选择 **Full** 或 **Full (strict)** 模式

### Q: 修改代码后网站没有更新？
**A**: Cloudflare Pages 自动部署通常需要 1-3 分钟。可以在 **Deployments** 标签查看部署状态。

### Q: 图片加载很慢？
**A**: 可以在 Cloudflare 中启用图片优化：
1. 进入域名设置 → **Speed** → **Optimization**
2. 启用 **Polish**（需要付费计划）

### Q: 网站在 Edge/Safari 无限刷新？
**A**: 浏览器语言设置导致。检查：
1. Network 面板是否有 308 重定向循环
2. 清除 localStorage：`localStorage.clear()`
3. 确认语言检测脚本包含当前页面检查

### Q: Legal 页面占位符未替换？
**A**:
1. 检查环境变量（`REAL_NAME`、`REAL_EMAIL`、`REAL_ADDRESS`）已设置
2. 查看 Real-time Logs 确认 Functions 执行
3. 确认访问路径正确（`/legal` 不是 `/legal.html`）

---

## 后续维护

### 更新网站内容

1. 修改 `website/` 目录下的文件
2. 提交到 GitHub：
   ```bash
   git add .
   git commit -m "update: description of changes"
   git push origin main
   ```
3. Cloudflare Pages 会自动检测并重新部署

### 查看部署历史

进入 Pages 项目 → **Deployments** 标签，可以查看所有部署历史和回滚到之前的版本。

### 监控流量

进入 Pages 项目 → **Analytics** 标签，可以查看访问统计。

---

## 部署检查清单

部署完成后，使用此清单验证：

**基础功能**：
- [ ] 网站可通过 `https://u4c.fi5h.xyz` 访问
- [ ] SSL 证书有效
- [ ] 所有 4 种语言版本正常访问
- [ ] 所有链接正常工作
- [ ] 图片全部加载
- [ ] 移动端响应式布局正常

**跨浏览器测试**：
- [ ] Chrome（英语/中文）无无限刷新
- [ ] Safari（中文）无无限刷新
- [ ] Edge（中文）无无限刷新
- [ ] 隐私模式正常

**Pages Functions**：
- [ ] Legal 页面所有占位符已替换（姓名、邮箱、地址）
- [ ] 环境变量已设置（`REAL_NAME`、`REAL_EMAIL`、`REAL_ADDRESS`）
- [ ] Real-time Logs 显示 Functions 执行

---

**部署完成！** 🎉

网站地址：**https://u4c.fi5h.xyz**

