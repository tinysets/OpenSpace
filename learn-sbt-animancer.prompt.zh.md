从一个大型 Codex session 的预处理 evidence 包中，提炼 SBT / THS Animancer 相关的中文 Codex skill 草稿。

## 运行模式

- 当前任务模式：`{{TASK_MODE}}`。
- 当前外层 pass：{{RUN_INDEX}} / {{RUN_COUNT}}。
- 单次最大迭代预算：{{MAX_ITERATIONS}}。
- 原始 session：`{{SESSION_PATH}}`。
- evidence 目录：`{{EVIDENCE_DIR}}`。
- chunk 报告目录：`{{CHUNK_REPORT_DIR}}`。
- 输出根目录：`{{OUTPUT_ROOT}}`。

下面有 `chunk` 和 `merge` 两种模式说明。只执行当前任务模式对应的章节，另一个模式章节只作为模板说明，不要执行其中的读取或写入要求。

重要：不要读取原始 150MB session JSONL。只能读取 `{{EVIDENCE_DIR}}` 下的预处理文件。预处理 evidence 默认只保留用户输入和模型输出，工具调用、事件流和 system 记录默认不进入 evidence；只有显式开启工具记录时，工具信息才可作为统计或文件/符号线索参考。

预处理器会强制保留所有用户发送的内容；这些记录即使没有命中关键词，也必须视为任务意图和取舍依据。不要把用户输入当作噪声丢弃。

## 固定输入

无论是哪种模式，都先读取：

- `{{EVIDENCE_DIR}}\manifest.json`
- `{{EVIDENCE_DIR}}\evidence_summary.md`
- `{{EVIDENCE_DIR}}\file_and_symbol_evidence.md`

不要一次性读取所有 chunk。不要把 `{{EVIDENCE_DIR}}\evidence.jsonl` 当成主要输入。

## chunk 模式

当当前任务模式是 `chunk` 时：

- 当前 chunk：{{CHUNK_INDEX}} / {{CHUNK_COUNT}}。
- 只额外读取这个 chunk 文件：`{{CHUNK_FILE}}`。
- 不要读取其他 chunk 文件。
- 不要写入 `{{DRAFT_DIR}}`。
- 不要生成最终 skill。
- 只写中文 chunk 报告到：`{{CHUNK_REPORT_FILE}}`。

chunk 报告必须包含：

- 这个 chunk 中出现的可复用工作流。
- SBT / THS Animancer 相关的领域概念、调用链、边界和约束。
- 可以进入最终 skill 的候选规则。
- 证据不足、不能写成 skill 的内容。
- 证据来源，至少包含 chunk 文件路径和关键 line 编号。
- 控制篇幅，不要贴长段原文；优先用结构化要点，目标长度约 1500 到 2500 个中文字符。

chunk 模式完成后输出 `<COMPLETE>`。

## merge 模式

当当前任务模式是 `merge` 时：

先读取这些 chunk 报告：

{{CHUNK_REPORTS}}

如果存在，也可以读取已有输出：

- `{{DRAFT_DIR}}`
- `{{REPORT_DIR}}`

然后合并所有 chunk 报告，生成或更新中文 Codex skill 草稿。

所有候选 skill 只能写到：

- `{{DRAFT_DIR}}`

最多写 `{{DRAFT_LIMIT}}` 个候选目录。每个候选目录必须包含 `SKILL.md`。

`SKILL.md` 必须满足：

- 使用 YAML frontmatter。
- `name` 用英文小写 slug。
- `description` 用中文。
- 正文必须全部使用中文。
- 必须包含：触发条件、输入、输出、步骤、验证方式、失败模式、不要做什么、证据来源。

merge 模式必须写中文总报告到：

- `{{REPORT_FILE}}`

如果 `{{IS_FINAL_PASS}}` 是 `true`，还要写或刷新：

- `{{REPORT_DIR}}\sbt-animancer-learning-report.md`

总报告必须说明：

- 读取了哪些 chunk 报告。
- 生成、修改或拒绝了哪些候选 skill。
- 哪些内容证据不足，不能写成 skill。
- 下一步人工 review 要看哪些文件。

merge 模式完成后输出 `<COMPLETE>`。

## skill 主题范围

围绕 SBT / THS Animancer、Unity 动画系统、Evaluate 链路、Playable/Animator 边界、低频更新、性能分析、UE 对照、调用链解释等主题，提炼有证据支撑的中文 Codex skill。

每个候选 skill 必须是可复用工作流，不要变成一次性项目笔记。可以保留必要的领域词，例如：

- `THSAnimConponentAnimancer`
- `THSLowAnimancerUpdateRate`
- `THSAnimancerDynamicUpdateRate`
- `runtimeAnimatorController`
- `Evaluate`
- `Playable`
- `Animator`
- `Profiler.BeginSample`
- `FAnimTickRecord`
- `SyncGroup`
- `BlendSpace`

## 安全边界

不要修改：

- `{{RUNTIME_DIR}}`
- `C:\Users\lihang.zhao\.codex\skills`
- 原始 session JSONL

不要上传任何内容到云端。
