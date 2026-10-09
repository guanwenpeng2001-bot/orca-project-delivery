# 架构

[English](../architecture.md) | **简体中文**

本文说明 `orca-project-delivery` 的设计：它分离的两个平面、它从不复制的权威、它路由到的角色、工作流和 Skill、它的 Git 证据模型、它的协调者锁，以及把这一切约束在一起的不变量。

## 控制平面与交付平面

本包严格分离三个 Git 平面：

| 平面 | 上面有什么 | 上面绝不发生什么 |
| --- | --- | --- |
| **控制平面** — 协调者控制工作树，位于控制分支 | 一个协调者智能体、项目 `AGENTS.md`、`.dev-work/` 过程状态、编排上下文 | 不开发源码、不作为任务基线、不合并、不审查、不做最终验证。它的 HEAD 可以落后，且绝不是交付证据。 |
| **交付平面** — 唯一的 `delivery_branch` | 已审查、已接受的源码。默认任务基线、集成目标，以及最终验证的来源 | 过程产物（`.dev-work/`、方案、报告）永不进入。 |
| **任务平面** — 每任务的分支与工作树 | 每个任务的隔离工作，包括只读的侦察、审计、审查和验证任务 | 一条分支上没有第二个写者；工作者从不合并自己的分支。 |

交付分支在受理时由 `scripts/bootstrap-project.ps1` 解析一次，顺序是：用户显式给出的分支 → `origin/HEAD` → `init.defaultBranch`（当该本地分支存在时）→ 本地 `main` → 本地 `master` → 当前分支。选择及其来源会被记录。引导会拒绝位于已解析交付分支上的控制工作树；显式覆盖是承认一次违规，而不是开辟一条正常路径。

## 系统边界与权威

四个权威，各自只拥有一种真相：

| 权威 | 拥有 |
| --- | --- |
| **Git** | 源码、分支、提交、集成真相。 |
| **Orca Runtime** | Run、Task、Dispatch、Worker、Message、Gate、生命周期真相。 |
| **`.dev-work/`**（仅控制树） | 业务阶段、映射、方案、报告、决策、证据 — 绝不是第二套生命周期数据库。 |
| **本 Skill** | 工作流、角色 / Skill / 模型路由、降级规则、输入组装。 |

在任何编排动词之前，协调者加载已安装的全局 `orchestration` Skill，并用当前 `--help` 确认语法；本包把业务动作映射到运行时概念；命令示例必须对照已安装的合同检查。只有协调者编辑全局过程状态；工作者只写分配给自己的报告路径。

## 12 个角色

每个任务一个主角色，按交付物经 `routing/role-selection.json` 选择。身份来自角色，方法来自专业 Skill，目标来自任务。

| 角色 | 类别 | 默认 Skill | 模型链（默认在索引 1） |
| --- | --- | --- | --- |
| codebase-scout | research | codebase-reconnaissance | haiku low → **haiku medium** → haiku high → sonnet medium |
| technical-researcher | research | technical-research | haiku medium → **haiku high** → sonnet medium → sonnet high |
| issue-investigator | research | systematic-debugging, codebase-reconnaissance | haiku high → **sonnet medium** → sonnet high → opus medium |
| requirements-analyst | product | requirements-analysis, product-discovery | sonnet medium → **sonnet high** → opus medium → opus high |
| solution-planner | architecture | implementation-planning, solution-architecture | opus high → **fable high** → fable xhigh → fable max |
| plan-adjudicator | architecture | implementation-planning, solution-architecture | fable high → **fable xhigh** → fable max |
| software-architect | architecture | solution-architecture | opus xhigh → **fable high** → fable xhigh |
| software-implementer | engineering | test-driven-development, integration-verification | sonnet medium → **sonnet high** → sonnet xhigh → opus medium |
| code-reviewer | quality | code-review, integration-verification | sonnet xhigh → **opus high** → opus xhigh → fable high |
| security-reviewer | quality | security-review, code-review | opus high → **opus xhigh** → fable high |
| release-verifier | quality | integration-verification | sonnet high → **opus high** → opus xhigh |
| merge-resolver | quality | merge-conflict-resolution, integration-verification | sonnet medium → **sonnet high** → opus medium |

互相冲突的身份 — 设计、实施、独立审查 — 拆成不同的任务。升档沿链向右一步（先提推理档，再提档位）；降档需要明确的速率限制、配额或模型不可用证据，且绝不低于角色的最低档。

## 4 个工作流

经 `routing/workflow-selection.json` 选择；每个在 `workflows/` 下有完整定义。深度随证据自适应 — light、standard 或 high-risk — 选择以及任何规模缩减都会被记录。

| 工作流 | 何时 | 阶段形状 |
| --- | --- | --- |
| feature-development（默认） | 目标是新增或改变的产品 / 系统行为 | intake → reconnaissance → plan → task graph → implementation → review → final verification |
| bug-fix | 目标是缺陷修正；复现或回归是核心 | intake → reproduction → investigation → fix planning → implementation → review → integration and verification |
| refactor | 外部行为保持稳定；内部结构是目标 | define invariants → reconnaissance → refactor plan → implementation → review → integration |
| audit | 目标是评估 / 发现项；实施不是初始目标 | intake → dynamic audit fan-out → finding contract → validation and deduplication → optional remediation |

high-risk 深度会在任务图之前插入并行侦察、独立方案、裁决和架构，并在实施期间插入审查循环。

## 16 个专业 Skill

Skill 随包位于 `skills/` 目录，以 `explicit-path`（任务中写明的 `SKILL.md` 绝对路径）交付给工作者；作为回退，也可以用 `inline-extract`，并记录来源路径和哈希。单独一个 Skill 名称绝不是加载证据，Skill 只提供方法 — 它不能扩大任务范围，也不能授予编排控制。

| Skill | 用途 |
| --- | --- |
| codebase-reconnaissance | 回答关于代码、分支、历史、配置和测试的有范围事实问题，不修改源码 |
| technical-research | 从一手来源和可复现实验研究当前技术行为 |
| product-discovery | 把模糊请求变成已验证的问题、用户、结果、范围和非目标 |
| product-design | 设计用户流程、信息架构、交互状态和可测试的 UX 验收 |
| requirements-analysis | 把目标和证据转成可追溯、可测试的需求 |
| solution-architecture | 设计最小的边界、职责、接口、迁移和回滚 |
| api-design | 设计稳定的 HTTP、RPC、事件、CLI 或模块合同 |
| database-design | 设计数据模型、约束、迁移和回滚 |
| implementation-planning | 把已批准的设计变成小的、带依赖意识的任务 |
| test-driven-development | 用 RED-GREEN-REFACTOR 证据实现行为 |
| systematic-debugging | 通过假设检验复现、隔离、解释、修复并验证缺陷 |
| code-review | 集成前做独立的、基于证据的审查 |
| security-review | 审查信任边界、认证、密钥、注入和滥用路径 |
| performance-review | 测量并分析延迟、吞吐、复杂度和容量 |
| integration-verification | 用命令和运行时证据验证任务与最终交付的验收 |
| merge-conflict-resolution | 依据分支意图、历史和测试解决 Git 合并冲突 |

## 证据模型

`scripts/validate-git-evidence.ps1` 是一个**只读**校验器，校验协调者根据观察写出的 JSON 证据文档。协调者先收集并书写，再校验，并且只在相关范围得到 `PASS` 之后才行动。校验器从不写 JSON、不跑测试、不合并，也不查询运行时。PASS 不能认证一条工作者消息，也不能证明记录的测试命令真的跑过；协调者必须核验 Runtime 归属并收集实际命令结果。一条结论为 CHANGES_REQUIRED 或 UNVERIFIABLE 的有效审查记录仍可以通过 `review` 阶段，所以校验 PASS 本身不是审查批准。

每任务证据位于 `runs/<run>/evidence/git/<task-key>.json`；一次运行恰好有一份终态记录，位于 `runs/<run>/evidence/git/run-final-verification.json`。任务证据状态是 `source-registered` → `reviewed` → `integrated`；合并前是 `reviewed` 之内的一个检查点，终态属于运行记录，从不属于每任务文件。

六个校验阶段：

| 阶段 | 门 | 检查什么 |
| --- | --- | --- |
| `sourceRegistered` | 匹配且活动的 `worker_done` 之后 | Schema、运行 / 路径 / 指派范围、记录的提交是否存在 |
| `review` | 独立审查被记录之后 | 审查者独立性（Task 与 Dispatch 都不同于源码工作者的）、目标 / 基线绑定、基线是目标的祖先、APPROVED 的目标是干净的 |
| `preMerge` | 最新 APPROVED 审查之后，且仍为 `reviewed` | 准入绑定批准的 SHA；活动源码 HEAD 等于它；源码与交付工作树干净；交付 HEAD 等于记录的基线 |
| `postMerge` | 实际合并加上在 `headAfter` 的新鲜检查之后 | 集成结果、合并证据（`git merge --no-edit <branch>`，退出码 0，无冲突）、祖先关系、绑定到 `headAfter` 的验证检查 |
| `final` | 所有预定集成之后，来自干净的独立验证工作树 | 唯一的运行终态记录、verified + READY、对已集成任务的完整精确覆盖、检查位于当前交付 HEAD |
| `audit` | 任何时候，针对历史运行 | Schema / 提交加上与状态相符的检查，**没有**活动 HEAD 相等或干净树的要求 |

**时刻等式与时间不变关系。** 活动阶段断言的是*在校验那一刻*必须成立的相等 — 源码分支 HEAD 等于批准的 SHA，交付 HEAD 等于记录的基线，树是干净的。`audit` 阶段检查历史绑定、记录的检查、提交存在性和祖先关系，不把它们与活动分支 HEAD 或工作树干净程度比较。历史任务记录在 `final` 下也使用历史检查；单独选择一个任务并不能确立运行完成。相对地，运行范围的 `final`（或规范的运行终态选择器）要求运行终态目标等于当前交付 HEAD。因此历史运行终态在交付推进之后可以合法地 FAIL `final`，同时仍通过 `audit`。历史 `headAfter` 仍是后来终态目标的祖先；它不必等于该目标。

校验器的退出语义：`PASS` 只对所选范围以 0 退出；`NOT_APPLICABLE` 也以 0 退出，且不是验收；`FAIL` 以 1 退出，在证据重建之前阻止合并或 READY 声明。

## 协调者锁与释放

运行时**没有协调者锁原语** — 同一工作树里的两个终端可以各自不受检查地创建运行。因此锁是存放在 `.dev-work/coordinator-lock.json` 中的本地约定，由 `scripts/bootstrap-project.ps1` 写入，在每个协调者都遵守它时保护一个工作树。

存活性有三种状态，通过记录的终端句柄探测：

| 状态 | 判定 | 引导行为 |
| --- | --- | --- |
| `live` | 终端探测返回 ok | 拒绝：一个存活的协调者拥有此工作树 |
| `dead` | 记录了句柄且探测失败 | 警告，归档旧锁，接管 |
| `unknown` | 没有句柄、PATH 上没有运行时，或响应无法解析 | 拒绝 — 缺席不是持有者已死的证明 |

释放使用 `scripts/release-coordinator.ps1 -ConfirmRunClosed`：它报告可回收的工作者（不可验证的结果如实报告，绝不当作失败），归档活动运行和锁文件，把锁标为 `released` 并带时间戳而不是删除它，然后删除 `active-run.json`。之后的引导看到 `released` 的持有者，将其归档并有意识地接管。绝不为了绕过释放而删除锁文件，也绝不用全局编排重置来清理一次运行。

## 12 条必守不变量

引自 `SKILL.md`；本包中的每一个工作流决定都服从它们。

| # | 不变量（原文） |
| --- | --- |
| 1 | Every Task, including read-only work, has an isolated branch and worktree. |
| 2 | One task branch has one writer at a time; replacement never creates a concurrent writer. |
| 3 | Self-check is not independent review; reviewers do not edit source; findings require fix Tasks and re-review. |
| 4 | Silence, empty waits and unverifiable observations do not prove failure, quota exhaustion or process exit. |
| 5 | Each run has one `delivery_branch`: explicit user choice, otherwise `origin/HEAD` → existing `init.defaultBranch` → `main` → `master` → current branch; record the source and integrate directly there. |
| 6 | `.dev-work/` exists only in the control tree; its global state belongs to the coordinator, not workers or a duplicate runtime database. |
| 7 | One active coordinator holds the control-tree lock; use live/dead/unknown evidence, release by marking, never delete the lock or use orchestration reset. |
| 8 | Record requested and effective values separately; only the first launch receipt proves effective values. |
| 9 | Installed global Orca Skills and current help govern commands; do not embed stale command lines. |
| 10 | Process artifacts never enter `delivery_branch`; inspect Git status and diff before commit or merge. |
| 11 | The control branch is neither development nor integration source; its HEAD may lag and is not current delivery evidence. |
| 12 | Review the actual implementation baseline; final verification uses a clean worktree from the latest `delivery_branch`, marking unverifiable evidence explicitly. |

中文释义：

1. 每个任务，包括只读工作，都有隔离的分支和工作树。
2. 一条任务分支同一时刻只有一个写者；替换绝不制造并发写者。
3. 自检不是独立审查；审查者不编辑源码；发现项需要修复任务和重新审查。
4. 沉默、空等待和不可验证的观察不能证明失败、配额耗尽或进程退出。
5. 每次运行有一个 `delivery_branch`：用户显式选择，否则 `origin/HEAD` → 存在的 `init.defaultBranch` → `main` → `master` → 当前分支；记录来源并直接在那里集成。
6. `.dev-work/` 只存在于控制树；其全局状态属于协调者，不属于工作者，也不是第二套运行时数据库。
7. 一个活动协调者持有控制树锁；使用 live / dead / unknown 证据，以标记方式释放，绝不删除锁或使用编排重置。
8. 请求值与生效值分开记录；只有第一次启动回执能证明生效值。
9. 已安装的全局 Orca Skill 和当前帮助管辖命令；不要嵌入过时的命令行。
10. 过程产物永不进入 `delivery_branch`；提交或合并前检查 Git 状态和 diff。
11. 控制分支既不是开发来源也不是集成来源；它的 HEAD 可以落后，且不是当前交付证据。
12. 审查实际的实现基线；最终验证使用来自最新 `delivery_branch` 的干净工作树，并明确标记不可验证的证据。

离线验收套件（`scripts/verify-package.ps1`）强制本设计的结构侧面 — 路由链单调性、角色 / Skill 路径存在性、17 节入口大纲、仅 Claude 的内容、编码，以及负面证据变异 — 因此本包可以在没有运行时的情况下被验证。
