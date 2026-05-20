从本地 Codex 历史中长跑多轮提炼可复用的中文 Codex skills。

## 运行模式

- 最大迭代预算：{{MAX_ITERATIONS}} 轮。
- 当前外层循环 pass：{{RUN_INDEX}} / {{RUN_COUNT}}。
- raw 模式：{{RAW_MODE}}。
- 额外指定 session：`{{SESSION_SOURCE}}`。
- 如果 raw 模式是 `no-raw`：不要读取原始 session JSONL 文件，只使用 `MEMORY.md` 和 `rollout_summaries`。
- 如果 raw 模式是 `raw`：可以在先用索引或 `MEMORY.md` 选出相关会话后，只读取少量必要的原始 session JSONL 文件；不要批量扫描全部 session。
- 如果 raw 模式是 `single-session`：除了 `MEMORY.md` 和 `rollout_summaries`，只允许读取“额外指定 session”这一份 session 作为原始证据；不要读取其他原始 session JSONL。如果额外指定 session 为空或不存在，必须在报告里说明并停止读取原始 session。

## 输入范围

先读取：

- `{{CODEX_HOME}}\memories\MEMORY.md`
- `{{CODEX_HOME}}\memories\rollout_summaries`

如果 `{{SESSION_SOURCE}}` 不是空字符串，把它作为额外证据源读取。它可能是一个 `.jsonl` 文件路径，也可能是一个 session id；如果是 session id，只能通过 `{{CODEX_HOME}}\session_index.jsonl` 或 `{{CODEX_HOME}}\sessions` 定位这一条 session，不能扩展扫描其他原始会话内容。

可以多轮迭代、归纳、对比、合并和修订，但不要为了凑数量虚构 skill。

如果当前 pass 不是第 1 轮，必须先读取已有输出：

- `{{DRAFT_DIR}}`
- `{{REPORT_DIR}}`

然后把本 pass 当作 review/refine pass：

- 检查已有 draft 是否符合中文 skill 格式。
- 补充缺失的触发条件、输入、输出、验证方式、失败模式和不要做什么。
- 合并重复或高度相似的候选。
- 只在证据足够时新增候选。
- 不要删除已有文件；如果认为某个候选应该删除或合并，在报告中标记，而不是直接删除。

## 提炼标准

只提炼有证据支撑的可复用工作流。每个候选 skill 必须清楚说明：

- 触发条件
- 输入
- 输出
- 步骤
- 验证方式
- 失败模式
- 不要做什么
- 隔离目录和 review gate

必须脱敏 secrets、token、账号标识、私有 URL 和一次性项目细节。

## 输出要求

所有候选 skill 只能写到：

- `{{DRAFT_DIR}}`

最多写 `{{DRAFT_LIMIT}}` 个候选目录。每个候选目录必须包含 `SKILL.md`。

`SKILL.md` 必须满足：

- 使用 YAML frontmatter。
- `name` 用英文小写 slug。
- `description` 用中文。
- 正文必须全部使用中文。
- 内容要像 Codex skill，可以直接用于指导未来工作，而不是普通聊天总结。

还要写一份中文总结报告到：

- `{{REPORT_DIR}}`

每个 pass 都要写或刷新一份中文报告。报告文件名必须包含当前 pass 编号，例如 `codex-skills-extraction-report-pass-{{RUN_INDEX}}.md`。最后一个 pass 还要写或刷新 `codex-skills-extraction-report.md` 作为总报告。

报告必须说明：

- 读取了哪些证据。
- 生成了哪些 draft。
- 哪些候选被拒绝，以及原因。
- 下一步如何人工 review。

## 安全边界

不要修改：

- `{{CODEX_HOME}}\skills`
- `{{RUNTIME_DIR}}`

不要上传任何内容到云端。
