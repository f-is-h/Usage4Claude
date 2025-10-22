# Filesystem 操作约束准则

> 本文档定义了你（Claude）在使用 Filesystem MCP 工具访问真实文件系统时必须遵守的行为约束。

## 🚨 强制性约束

### 约束 1：工具选择

**你必须：**
- 使用 Filesystem MCP 工具访问用户的真实文件系统
- 可用工具：`Filesystem:read_file`, `Filesystem:read_multiple_files`, `Filesystem:edit_file`, `Filesystem:write_file`, `Filesystem:create_directory`, `Filesystem:list_directory`, `Filesystem:search_files`, `Filesystem:move_file`, `Filesystem:get_file_info`

**你绝对不能：**
- 使用 `bash_tool` 执行文件读取命令（如 `cat`, `grep`, `sed`, `awk`, `less`, `head`, `tail`）
- 使用 `bash_tool` 执行文件操作命令（如 `cp`, `mv`, `rm`, `mkdir`, `touch`, `chmod`）
- 使用 `bash_tool` 执行文件搜索命令（如 `find`, `locate`, `ls`）

**原因：** bash_tool 运行在隔离容器环境中（/home/claude），无法访问用户的真实文件系统（如 /Users/iMac/Coding）。

**例外：** 你可以使用 bash_tool 执行以下操作：
- 运行程序和脚本（`npm run`, `python script.py`, `node app.js`）
- 安装依赖（`pip install`, `npm install`, `brew install`）
- Git 操作（`git commit`, `git push`, `git status`）
- 编译构建（`make`, `cargo build`, `mvn package`）

---

### 约束 2：批量操作强制要求

**当需要读取多个文件时，你必须：**
- 使用 `Filesystem:read_multiple_files` 一次性读取所有目标文件
- 绝不连续调用多次 `Filesystem:read_file`

**正确示例：**
```javascript
Filesystem:read_multiple_files({
  paths: [
    "/path/to/file1.js",
    "/path/to/file2.js", 
    "/path/to/file3.js"
  ]
})
```

**违规示例（禁止）：**
```javascript
Filesystem:read_file({ path: "/path/to/file1.js" })
Filesystem:read_file({ path: "/path/to/file2.js" })
Filesystem:read_file({ path: "/path/to/file3.js" })
```

**效率要求：** 批量操作可节省 50-70% 的 Token，你必须优先选择批量工具。

---

### 约束 3：增量编辑强制要求

**当需要修改文件内容时，你必须：**

1. **优先使用 `Filesystem:edit_file` 进行部分修改**
   - 适用于：修改配置项、替换特定文本、更新函数片段
   - 不适用于：需要完全重写的文件

2. **使用 `dryRun: true` 预览重要变更**
   - 对于用户未明确确认的修改，先预览
   - 展示预览结果后等待用户确认

3. **禁止的低效模式：**
   - 读取整个文件 → 修改内容 → 重写整个文件
   - 这种模式仅在必须完全重写时使用

**正确示例：**
```javascript
Filesystem:edit_file({
  path: "/path/to/config.json",
  edits: [
    {
      oldText: '"version": "1.0.0"',
      newText: '"version": "2.0.0"'
    }
  ],
  dryRun: true
})
```

**edit_file 使用要求：**
- `oldText` 必须与文件中的文本**完全一致**（包括空格、换行、缩进）
- 如果匹配失败，你必须使用 `read_file` 查看实际内容，然后调整 `oldText`
- 不要猜测文本内容，必须基于实际文件内容进行编辑

---

### 约束 4：路径和搜索要求

**你必须：**
1. **始终使用绝对路径**
   - 正确：`/Users/iMac/Coding/Projects/Usage4Claude/src/App.tsx`
   - 错误：`./src/App.tsx`, `../Usage4Claude/src/App.tsx`

2. **直接使用 `search_files`，不要先 list 再过滤**
   - 正确：`Filesystem:search_files({ path: "/path", pattern: "*.tsx" })`
   - 错误：先 `list_directory` 然后手动过滤结果

3. **在操作前向用户确认关键信息**
   - 列出将要操作的文件路径
   - 说明将要执行的具体操作
   - 等待用户确认后再执行

---

### 约束 5：操作流程

**你必须遵循以下流程：**

```
1. 接收用户任务
   ↓
2. 使用 search_files 或 list_directory 定位目标文件
   ↓  
3. 向用户展示：
   - 找到的文件列表
   - 计划执行的操作
   ↓
4. 等待用户回复"确认"或"继续"
   ↓
5. 使用最高效的工具执行操作
   ↓
6. 简洁报告结果
```

**示例确认信息：**
```
我找到了以下文件：
1. /path/to/file1.js
2. /path/to/file2.js

我将执行以下操作：
- 将所有 "oldText" 替换为 "newText"

请回复"确认"继续执行。
```

---

### 约束 6：错误处理

**当操作失败时，你必须：**

1. **明确说明失败原因**
   - 文件不存在、路径错误、权限不足
   - edit_file 的 oldText 不匹配
   - 目录不存在

2. **提供具体的解决方案**
   - 使用 `get_file_info` 确认文件状态
   - 使用 `read_file` 查看实际内容后重新尝试
   - 建议用户检查路径或权限

3. **不要盲目重试相同的操作**
   - 分析原因后调整策略
   - 不要重复执行已经失败的命令

---

### 约束 7：结果报告

**操作成功时，你必须提供简洁报告：**

```
✅ 操作完成

修改的文件：
- /path/to/file1.js (3 处变更)
- /path/to/file2.js (1 处变更)

总计：2 个文件，4 处变更
```

**禁止冗长描述：**
- 不要描述你如何思考的过程
- 不要解释你使用了哪些工具
- 不要重复用户已知的信息
- 直接给出结果和关键数据

**操作失败时的报告格式：**

```
❌ 操作失败

原因：文件中未找到匹配文本
文件：/path/to/file.js
查找：oldText

建议：我将读取该文件查看实际内容。
```

---

### 约束 8：安全要求

**对于敏感文件，你必须：**
- 操作前明确告知用户将修改什么内容
- 对于删除操作，要求用户明确确认
- 敏感文件包括：`.env`, `.git/config`, `credentials.json`, 系统配置文件

**对于大规模修改（10+ 个文件），你必须：**
- 提醒用户先备份或提交代码
- 使用 `dryRun: true` 预览所有变更
- 提供变更摘要供用户审核

---

### 约束 9：特殊场景处理

**大文件（>1000 行）：**
- 你必须使用 `edit_file` 进行部分修改
- 不要读取整个文件内容
- 如必须读取，说明原因并征得用户同意

**二进制文件（图片、视频、压缩包）：**
- 你只能执行移动、复制、删除、重命名操作
- 不要尝试读取或编辑内容
- 可以使用 `get_file_info` 获取元数据

**目录递归操作：**
- 使用 `directory_tree` 获取完整结构
- 在递归操作前评估文件数量
- 如果操作影响 20+ 个文件，向用户确认

---

## ✅ 操作前检查清单

在执行任何文件操作前，你必须确认：

- [ ] 我正在使用 Filesystem 工具而非 bash 命令
- [ ] 多个文件操作已合并为批量调用
- [ ] 文件修改优先考虑了 edit_file
- [ ] 使用的是绝对路径
- [ ] 已向用户展示操作计划并等待确认
- [ ] 重要变更使用了 dryRun 预览
- [ ] 准备了简洁的结果报告

---

## 📚 约束执行示例

### 示例 1：读取文件

**❌ 违规（使用 bash）：**
```
bash_tool: cat /path/to/file.js
```
*结果：找不到文件（bash 在容器中）*

**✅ 正确（使用 Filesystem）：**
```
Filesystem:read_file({ path: "/path/to/file.js" })
```

---

### 示例 2：批量读取

**❌ 违规（多次单独调用）：**
```
Filesystem:read_file({ path: "/path/to/file1.js" })
Filesystem:read_file({ path: "/path/to/file2.js" })
Filesystem:read_file({ path: "/path/to/file3.js" })
```

**✅ 正确（批量操作）：**
```
Filesystem:read_multiple_files({
  paths: ["/path/to/file1.js", "/path/to/file2.js", "/path/to/file3.js"]
})
```

---

### 示例 3：修改文件

**❌ 违规（读取→修改→重写）：**
```
1. Filesystem:read_file({ path: "/path/to/config.json" })
2. 在内存中修改内容
3. Filesystem:write_file({ path: "/path/to/config.json", content: "..." })
```

**✅ 正确（增量编辑）：**
```
Filesystem:edit_file({
  path: "/path/to/config.json",
  edits: [{
    oldText: '"port": 3000',
    newText: '"port": 8080'
  }],
  dryRun: true
})
```

---

### 示例 4：搜索文件

**❌ 违规（使用 bash find）：**
```
bash_tool: find /path -name "*.tsx" -type f
```

**✅ 正确（使用 search_files）：**
```
Filesystem:search_files({
  path: "/path/to/project",
  pattern: "*.tsx"
})
```

---

## 📌 核心要求总结

你必须严格遵守以下要求：

1. **永远使用 Filesystem MCP 工具**访问真实文件系统，绝不使用 bash 命令
2. **批量操作**：多个文件必须批量处理
3. **增量编辑**：文件修改优先使用 edit_file
4. **操作前确认**：向用户展示计划并等待确认
5. **结果简洁**：只报告核心信息
6. **绝对路径**：始终使用完整的绝对路径
7. **错误分析**：失败后分析原因再重试

**违反这些约束将导致：**
- 操作失败（bash 找不到真实文件）
- Token 浪费（未使用批量操作）
- 效率低下（未使用增量编辑）
- 用户体验差（未确认即执行、报告冗长）

---

*此文档定义了你在 Project 中操作文件系统的强制性行为约束。你必须严格遵守所有约束条款。*

*最后更新：2025年10月*
