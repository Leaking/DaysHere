---
name: update-spec
description: 更新项目的决策日志 / living spec（decisions.md 或 living-spec.md）
triggers:
  - decision
  - update spec
  - log change
  - append decision
---

# /update-spec - 项目决策日志更新技能

## 参数说明

- **无参数**：将本次会话的关键决策追加到 decisions.md
- **`promote`**：将 decisions.md 的精华提炼后合并进 CLAUDE.md，使 CLAUDE.md 反映最新架构状态

---

## 模式一：追加决策（默认，无参数）

### 核心指令

你的任务是维护项目的"活规范"和决策记录。

- 首选目标文件：项目根目录下的 decisions.md
  （如果不存在，检查 living-spec.md，或建议创建 decisions.md）
- 只记录真正重要的内容：
  - 架构/设计决策变更
  - 技术选型调整
  - 重大权衡理由
  - 发现的关键约束/风险/非功能性问题
  - 安全、性能、兼容性相关发现
- 不要记录琐碎实现细节（变量名、class 名、小调整等）

### 追加格式（严格遵守，append 到文件末尾）

```
## 变更记录 - {{current_date}}

- **上下文**：{{本次任务或 $ARGUMENTS 提供的说明}}
- **关键变更**
  - ...
- **理由**
- **后续影响**
```

### 执行流程

1. 读取 decisions.md / living-spec.md（如果存在）
2. 回顾当前会话：最近代码变更、plan、思考、<decision-update> 等
3. 提炼 1–4 条值得长期保留的关键点
4. 生成追加内容，用代码块 + diff 风格展示
5. 询问："是否批准追加到 decisions.md？（yes / no / edit）"
6. 得到批准后才真正写入文件

如果没有值得记录的内容，直接回复："本次无重大决策变更，无需更新。"

---

## 模式二：提炼并更新 CLAUDE.md（参数：promote）

### 核心指令

将 decisions.md 中积累的决策记录提炼压缩，合并进 CLAUDE.md，使 CLAUDE.md 始终反映项目的最新架构状态。

### 执行流程

1. 读取 CLAUDE.md 和 decisions.md（必须两个都存在才能继续）
2. 分析 decisions.md 中所有变更记录，识别：
   - 与 CLAUDE.md 现有内容**冲突或过时**的描述 → 需要替换
   - CLAUDE.md **缺失但重要**的新架构信息 → 需要补充
   - 仅属于历史过程、不影响当前架构的内容 → 忽略
3. 生成对 CLAUDE.md 的最小化修改方案（diff 风格展示），原则：
   - **保持 CLAUDE.md 精简**：不堆砌历史，只留对开发者有指导意义的内容
   - **不改变 CLAUDE.md 整体结构**：在对应章节就地更新，而非追加
   - **语言风格一致**：延续 CLAUDE.md 已有的简洁技术风格
4. 展示变更 diff，询问："是否批准更新 CLAUDE.md？（yes / no / edit）"
5. 得到批准后写入 CLAUDE.md
6. 询问："是否同时清理 decisions.md 中已被吸收的条目？（yes / no）"
7. 得到批准后，删除或归档已合并的变更记录，保留未被吸收的部分
