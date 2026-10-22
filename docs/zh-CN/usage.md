# 使用

[English](../usage.md) | **简体中文**

版本 2 项目注册、混合绑定、解析后的依赖选择及原位置同级资源，见[已安装外部 Skill 演练](external-skills.md)。包内 Skill 不需要单独安装。

本走读从协调者的位置演示一次完整交付。它概括 `SKILL.md` 及其参考所定义的工作流；运行时以该 Skill 本身为权威，每一条 Orca 命令则以已安装的全局 `orchestration` Skill 加上当前 `--help` 输出为权威。

本指南面向3.0.0：**46 个 Skill、16 个角色、4 个工作流**。按任务选择方法：共享 token 使用 `design-system`，领域不变量使用 `domain-modeling`，升级使用 `migration-upgrade`，工具协议使用 `mcp-server-development`。图示、本地化、Skill 评估和字幕各有专门 Skill。输入、命令与验证边界见[能力指南](professional-capabilities.md)和[离线教程](professional-capability-tutorial.md)。新增 Skill 不新增角色，也不扩大权限。

## 开始一次交付（协调者入口）

你在**协调者控制工作树**里运行本 Skill — 项目在一条控制分支上的检出，而这条分支*不是*交付分支。一个工作树只承载一个协调者；控制工作树从不开发或集成源码。

引导顺序（来自 `SKILL.md`）：

1. 定位协调者控制工作树。若怀疑已有第二个协调者，先按 `references/coordinator-lock.md` 处理，再做其他事：存活的协调者会被拒绝；未知的锁状态保留待查，绝不绕过。
2. 保留已有的项目 `AGENTS.md`；仅当不存在时才从 `templates/AGENTS.md` 创建。
3. 用 `scripts/bootstrap-project.ps1` 初始化或校验 `.dev-work/`。脚本会解析并记录交付分支、写入协调者锁，并拒绝在交付分支本身上运行。
4. 引导保留已有 `.env.example` 和 `project-config.example.json`，仅创建缺失示例；通过同一克隆各工作树共享的本地 Git `info/exclude` 排除 `/AGENTS.md`、`/.dev-work/` 和 `/.env`。
5. 用 `scripts/create-run.ps1` 创建或恢复运行记录，然后创建或绑定 Orca Run。
6. 运行 `scripts/probe-claude-capabilities.ps1`，检查它的 JSON 和警告，而不只是退出码。任何 `launched` 结论都是异常的哨兵启动：停止、标为未验证，并升级。
7. 在控制树中记录协调者、交付分支、Orca Run id、schema 版本和探测证据。

要从协调者会话开始，明确要求它读取 `~/.agents/skills/orca-project-delivery/SKILL.md`，并给出目标、交付分支、范围和验收条件。例如：

```text
Use the installed orca-project-delivery Skill as coordinator.
Deliver a validated configuration change into main.
Inspect the repository to determine the exact scope and tests, use isolated
Tasks, and obtain independent review before integration.
```

这些包脚本示例给协调者用。把 `<project>` 换成它的控制工作树，且该工作树已在一条不同的控制分支上。这些命令不派发工作者，也不创建 Orca Run：

```powershell
$package = Join-Path $env:USERPROFILE '.agents/skills/orca-project-delivery'
pwsh -NoProfile -File "$package/scripts/bootstrap-project.ps1" -ProjectRoot '<project>' -DeliveryBranch main
pwsh -NoProfile -File "$package/scripts/create-run.ps1" -ProjectRoot '<project>' -Objective 'Validate configuration behavior' -Workflow feature-development -RunSlug configuration-validation -DeliveryBranch main
pwsh -NoProfile -File "$package/scripts/probe-claude-capabilities.ps1" -ProjectRoot '<project>'
pwsh -NoProfile -File "$package/scripts/validate-run.ps1" -ProjectRoot '<project>'
```

通过已安装的全局 Skill 绑定真正的 Orca Run，并记录该绑定。绝不要把模板占位符当作观察结果抄进活动记录。

## 交付的端到端过程

标准运行的阶段顺序：

```text
intake -> reconnaissance -> design (conditional, verdict recorded) -> plan -> task graph -> dispatch
       -> wait & process -> review -> integration -> final verification -> close
```

### 1. 受理（Intake）

在运行状态中记录：目标、规模、交付分支、任何用户锁定的 Agent / 模型选择，以及副作用边界。用 `routing/workflow-selection.json` 选择工作流（`feature-development`、`bug-fix`、`refactor` 或 `audit`），以及深度 — light、standard 或 high-risk — 若缩小规模，记下原因。侦察结束后、规划开始前，将设计判断（`required` 或 `skipped`）及其原因和证据记录在运行状态的 `stageDecisions.design` 中。

### 2. 侦察

不要启动固定名单的侦察者。问：*哪些未知事实会实质改变方案、范围、风险或验收决定？* 每个独立信息域创建一个隔离的 Scout 任务，并行进行 — 当前代码与调用路径、既有过程记录、官方文档、日志与失败样本、配置与部署行为、用户反馈。当剩余未知不能改变做法时停止，或把它们明确记为不可验证。

### 3. 方案

若执行了设计阶段，其产出就是规划的输入。

使用方案规划者角色。当备选方案或风险实质存在时，派发上下文隔离的独立规划任务，并由方案裁决者决定。真正的产品歧义先由需求分析师解决。

### 4. 任务图

为每个任务写任务定义，并用 `scripts/assemble-task.ps1` 组装其输入。每个任务携带：一个主角色、必需（以及可选的条件）Skill、允许与禁止范围、分支与工作树合同、一条 `.dev-work` 报告路径、验收条件，以及 Orca Worker Contract。即使已有 Markdown 简报，也要把机器可读的指派记在 `runs/<run>/assignments/<task>.json` 下 — 包括请求的和生效的运行时值。只编码真实依赖；使用并行波次，避免深于 3–4 步的链。

组装会对照包内真实脚本及其声明参数逐条校验验收与测试命令，命令不可执行时组装失败、不写简报。审查简报可带 `reviewInput.deltaPaths` 并按 delta 缩放重验范围；标准简报点名最小相关套件，全量门禁留在合并后与终态验证。点名套件用 `scripts/verify-package.ps1 -Suites '<name>'` 运行，前置套件会自动补齐。`-SuiteTimeoutSeconds` 只为 package runtime 套件的子进程计时，其余检查沿用每子进程 60 秒的默认预算。

随包专业 Skill 从本包的 `skills/<skill-id>/SKILL.md` 解析。外部 Skill 必须在版本 2 项目配置中显式注册，见[外部 Skill](external-skills.md)。组装交付解析后的路径（`explicit-path`），或内联同一正文（`inline-extract`）。随包文件缺失时组装失败，不会静默回退到 `~/.agents/skills` 下的同级安装。随包 Skill 的出处写在 `skills/README.md`。见 [professional-skills.md](professional-skills.md)、[professional-capabilities.md](professional-capabilities.md) 和 [installation.md](installation.md)。检查安装、运行本地工具和依赖辅助脚本而不调用提供方的走读在 [professional-capability-tutorial.md](professional-capability-tutorial.md)。

组装把目录 `requires` 的名称/用途放在 Inputs and Dependencies 内，区分 Role 加必需 Skill 的依赖与条件 Skill。条件依赖仅在 Task 要求时激活。在执行主机上，以显式 `-ProjectRoot`、`-Role` 和会话内 `-Skills @(...)` 所选 ID 数组运行 `check-requirements.ps1`。辅助脚本不会代选 Role 默认 Skill。文件配置不代表当前 shell 已有这些值；授权子进程可以通过 `invoke-with-requirements.ps1` 接收所选文件变量，父进程环境保持不变。精确接口及离线走读见[扩展与配置](extending.md)。十段 Task 顺序及适用 `AGENTS.md` 最后保持不变。

### 5. 派发

任务**就绪**的条件是：真实依赖已通过各自的门成功结算 — 源码依赖只在它自己的审查*和*集成之后才算数，绝不只凭 `worker_done` — 写入范围与在途任务不相交，并且基线与路由可用。立即派发就绪任务（滚动派发）；不要为无关的在途工作设置批次屏障。

每次派发都走运行时的 worker-start 动词，使用 Claude 智能体，以及从 `routing/model-routing.json` 选出的路由。派发没有权限旗标：权限来自实际的 Claude 配置和用户的 Orca 设置，只记录，不臆造。

用 `scripts/dispatch-task.ps1` 从协调者捕获的 `worker-start --json` 回执（`-ReceiptPath`）记录本次派发：脚本推导请求值 / 生效值的核对结论，拒绝落点在协调者控制树或与任务定义矛盾的回执，写盘前先用 `schemas/assignment.schema.json` 校验指派，并且同一任务的重复在途派发默认被拒 — 除非 `-ForceReDispatch` 把先前派发记入 `runtime.previousDispatches`。记录 `runtime.mode` 与终端 `surface`；`structured` 工作者属于后台会话，下一次里程碑汇报必须明说。

执行循环和审查 / 集成的操作细节位于[执行循环参考](../../references/execution-loop.md)；派发和处理工作者前先阅读该参考。

### 6. 等待与处理

在运行时的 check 动词上等待；处理每一个问题和升级。确认每个 `worker_done` 属于活动 Dispatch 后再确认它，并决定每个终端的下一任所有者。每次确认结算之后，重新评估就绪状态并派发新就绪的任务。连续三次空等待之后，枚举工作者并按投影的下一步行动处理，必要时做有界的工作者读取。

对 `worker_done` 已确认的源码任务：把指派推进到 `review`；工作者写在指派报告路径下的报告会注明受审的提交。

### 7. 审查

源码任务 `worker_done` 确认之后，在隔离工作树中对实际实现分支做独立审查，与其他实施并行。审查者报告 `APPROVED`、`CHANGES_REQUIRED` 或 `UNVERIFIABLE`，从不编辑源码，并记录目标 / 基线 SHA。完成的审查报告归档到 `runs/<run>/reviews/`；报告中的提交绑定是裁决与受审提交之间的持久链接。被接受的发现项变成修复任务，随后重新审查。

### 8. 集成

每次批准之后，在检出了 `delivery_branch` 的工作树中串行合并（运行时没有合并原语 — 这是你自己的 `git merge`）。合并前一刻确认活动源码 HEAD 仍等于已批准的提交，且源码与交付工作树都干净；漂移需要重新审查。在集成后的 HEAD 运行完整验证套件，通过后才把源码依赖视为已结算。冲突时：中止，创建隔离的解决任务，独立审查它，并在同样条件下合并。

此后创建的任务以更新后的交付分支为基线，然后回收符合条件的工作树。

### 9. 最终验证

在**所有**预定变更都集成之后，针对最新交付分支，在干净、独立的工作树中派发发布验证者任务。只有它通过才授权 READY。这个屏障从不提前，也从不跳过。

### 10. 关闭

写链接到最终验证报告的最终报告，以及一份单独的用户决策报告，列出仍待决的事项。结算工作者，确认没有可回收资源残留，复查过程产物从未进入交付分支，然后用 `scripts/release-coordinator.ps1 -ConfirmRunClosed` 释放。把 `.dev-work/runs/<run>/` 留作本地历史。

## 选择角色与模型路由

按交付物为每个任务恰好选择一个主角色，使用 `routing/role-selection.json`；按 `routing/skill-selection.json` 从当前 `routing/skill-catalog.json` 目录中选 1–3 个必需 Skill，再为实质风险加 0–2 个条件 Skill。角色的模型路由来自 `routing/model-routing.json`：选定链，从默认档开始，绝不低于最低档。

默认路由（每个角色链的索引 1）：

| 角色 | 默认档位 / 推理档 |
| --- | --- |
| codebase-scout | haiku / medium |
| technical-researcher | haiku / high |
| issue-investigator | sonnet / medium |
| requirements-analyst | sonnet / high |
| solution-planner | fable / high |
| plan-adjudicator | fable / xhigh |
| software-architect | fable / high |
| software-implementer | sonnet / high |
| code-reviewer | opus / high |
| security-reviewer | opus / xhigh |
| release-verifier | opus / high |
| merge-resolver | sonnet / high |
| ui-designer | opus / medium |
| browser-test-engineer | sonnet / high |
| media-producer | sonnet / high |
| document-specialist | sonnet / high |

最后四个是 2.3.0 新增角色的当前路由。路由文件是权威；如果它与本表不一致，以文件为准。每个新角色做什么、拒绝什么，见[专业能力](professional-capabilities.md)。

升档沿链向右一步（先提推理档，再提档位）；降档只在有明确的速率限制、配额或模型不可用证据时发生，绝不因沉默而降。haiku 档优先使用带推理档的完整模型 id，被拒绝或不匹配时回退到不带推理档的别名。用户锁定的选择禁止一切自动变更。

## 分支与工作树约定

- 每个任务 — 包括只读的侦察、审计、审查和验证工作 — 都有自己的分支和工作树。默认基线是交付分支；任何其他基线都要记录原因。
- 一条任务分支同一时刻只有一个写者。替换写者需要证据表明旧写者已停止（或被隔离、围栏，或已明确交接），外加已结算的 Dispatch 和保留下来的 Git 状态交接。
- 工作者在报告前把授权的变更提交到自己的任务分支，并且从不合并自己的分支。
- 只读任务在指派中声明 `branch.mergeTarget: null`。
- 源码合并只发生在交付工作树中，串行，按依赖顺序，由协调者执行。

## 记录与报告位置

过程侧的一切都在控制工作树的 `.dev-work/` 下：

| 产物 | 路径（相对于 `.dev-work/`） |
| --- | --- |
| 运行状态、决策 | `runs/<run>/run-state.json`、`runs/<run>/decisions.md` |
| 机器可读指派 | `runs/<run>/assignments/<task>.json` |
| 工作者报告 | `runs/<run>/worker-reports/<task>.md` |
| 审查报告 | `runs/<run>/reviews/` |
| 最终验证报告 | `runs/<run>/verification/` |
| 交接 | `runs/<run>/handoffs/` |
| 能力探测 | `runtime/claude-capabilities.json` |
| 降级事件 | `runs/<run>/degradation-events.json` |
| 最终报告 | `runs/<run>/final-report.md` |

工作者只写分配给自己的报告路径；其余一切由协调者写。

## 阅读工作者回执

每次派发时，把你请求的和运行时实际启动的对照：

- **requested** — 你发出的字面 agent / model / effort；
- **effective** — 只取**第一次** `worker-start` 回执中 `launch.effective` 块的值；未能核验的保持 `null`；
- **verification** — `verified`、`mismatch` 或 `unverified`，并附证据。

三者都记入指派的 `runtime` 块。参数被接受并不能证明已生效：把路由当作已验证之前先调和 mismatch，并且绝不把请求值当作生效值。单独一个非零的启动回执并不能证明尝试失败 — 用 `references/failure-taxonomy.md` 检查 `failedStage` 和残留资源。

## 常见使用问题

**如何选择工作流？**
按目标匹配：缺陷修正 → `bug-fix`；评估 / 发现项 → `audit`；保持行为不变的结构调整 → `refactor`；新增或改变的行为 → `feature-development`（默认）。深度（light / standard / high-risk）跟着证据走；缩小规模时记录原因。

**如何知道任务已可派发？**
它的真实依赖已通过各自的门成功结算（源码依赖需要审查*和*集成，而不只是 `worker_done`），写入范围与在途任务不相交，并且基线与路由可用。任务一就绪就派发。

**每次派发必须记录什么？**
指派 JSON：请求的和生效的运行时值、权限模式、Skill 交付方式、Task / Dispatch id、分支 / 工作树 / 报告路径，以及任何回退原因 — 即使已有组装好的 Markdown 简报。

**何时可以合并已审查的分支？**
最新审查为 `APPROVED`、源码 HEAD 仍等于批准的 SHA，且源码树与交付树都干净之后。在交付工作树中串行合并，并在集成后的 HEAD 运行完整验证套件。

**审查返回 CHANGES_REQUIRED 怎么办？**
把被接受的发现项转成修复任务（新分支、新写者），重新审查修复，并更新准入。审查者从不自己改源码。

**工作者在运行中途发来问题或升级。现在怎么办？**
通过运行时的回复路径回答，让工作者继续。如果答案是用户决策，打开一个决策门，只挂起依赖它的任务 — 独立工作继续推进。

**两个任务可以写同一批文件吗？**
不可以。就绪任务的派发要求写入范围不相交；冲突的需求通过真实依赖排序，而不是并行。

**如何收尾？**
在来自最新交付分支的干净工作树上做最终验证并通过，报告已写，工作者已结算，确认过程产物不在交付分支上，然后执行 `scripts/release-coordinator.ps1 -ConfirmRunClosed`。
