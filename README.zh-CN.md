# Orca Project Delivery

[English](README.md) | **简体中文**

面向 Orca 与 Claude Code 用户的**仅协调者** Skill，把软件目标变成隔离、独立审查、集成并验证过的变更。

![Version](https://img.shields.io/badge/version-2.3.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)

这些指南描述已发布的 **2.3.0 包：38 个 Skill、16 个角色**。安装完整且匹配的版本，并在运行[能力教程](docs/zh-CN/professional-capability-tutorial.md)前核对 `VERSION`、两个目录和清单。版本不匹配就不是本版本。

Orca Project Delivery 是一个仅供协调者使用的 Skill，用 Claude Code 工作者智能体跑完整条软件交付流水线。它解决的问题是：在同一个仓库里监督许多自主智能体，同时不丢掉分支纪律、独立审查和可核验的证据。它写给担任协调者的人：你已经有 Orca（多代理 IDE）和 Claude Code，希望由隔离的工作者在明确合同下产出、审查、集成并做最终验证大型变更。

- [这是什么](#这是什么)
- [这不是什么](#这不是什么)
- [能力一览](#能力一览)
- [快速开始](#快速开始)
- [仓库结构](#仓库结构)
- [文档](#文档)
- [许可证](#许可证)

## 这是什么

一个协调者入口（`SKILL.md`），把项目交付从受理一直驱动到最终验证：

1. **受理（Intake）** — 记录目标、规模、交付分支、用户锁定的选择，以及副作用边界。
2. **动态侦察** — 每个独立信息域一个隔离的 Scout 任务，并行派发。
3. **方案** — 一名方案规划者；风险需要时再加多份方案和一个方案裁决者。
4. **任务图** — 自包含的任务，写明角色、Skill、分支、范围、验收条件和报告路径。
5. **派发与滚动执行** — 每个任务有自己的分支和工作树；真实依赖一结算，就绪任务就派发。
6. **独立审查** — 审查者不改源码；发现项变成修复任务，再重新审查。
7. **集成** — 协调者把已批准的分支串行合并进唯一的 `delivery_branch`，每个门都记录提交证据。
8. **最终验证** — 从最新交付分支拉出干净、独立的工作树；通过或被明确标为不可验证之前，运行不得关闭。

协调者的每一项断言都有书面记录：模型路由（请求值与生效值）、Git 证据（源码登记、审查、合并前准入、合并结果、运行终态覆盖）、降级事件，以及用户决策。

## 这不是什么

- **不是通用编排框架。** 它只定义一种业务工作流：用 Claude Code 工作者做项目交付。它不管理任意智能体舰队，也不管理其他智能体运行时。
- **不替代全局 Orca Skill。** 已安装的 `orchestration`、`orca-cli` 和 `orca-per-workspace-env` 仍是 Run / Task / Dispatch / Worker 生命周期、命令和回执的权威。本包把业务动作映射到运行时概念；命令示例请对照已安装 Skill 和当前帮助确认。
- **仅协调者。** 携带派发前言的工作者不得运行本 Skill。工作者只执行分配给它的任务、角色、专业 Skill、分支和报告合同。
- **依赖 Claude Code 与 Orca Runtime。** 所有工作者都是经 Orca 启动的 Claude Code 智能体；没有独立运行模式。
- **实践上仅 Windows。** 每个脚本都是 PowerShell 7，且只在 Windows 上运行过。没有其他平台的安装程序。
- **不通过包注册表分发。** 没有 npm 或 pip 包；安装就是普通的 Git 克隆或复制（见 [docs/zh-CN/installation.md](docs/zh-CN/installation.md)）。

## 能力一览

| 能力 | 说明 | 来源 |
| --- | --- | --- |
| 角色 | 16 个（研究、产品、架构、工程、质量、媒体） | `roles/catalog.json` |
| 专业 Skill | 38 个，随包位于 `skills/` | `routing/skill-catalog.json` |
| 工作流 | 4 个：feature-development、bug-fix、refactor、audit | `workflows/` |
| 自适应深度 | light / standard / high-risk 阶段链 | `routing/workflow-selection.json` |
| 模型路由 | 按角色在 haiku / sonnet / opus / fable 上排链，含推理档、默认档与最低档 | `routing/model-routing.json` |
| 必守不变量 | 12 条关于隔离、审查、证据与集成的约束 | `SKILL.md` |
| 辅助脚本 | PowerShell 引导、组装、依赖检查、限定子进程执行、校验和释放 | `scripts/` |
| 离线验收 | 完整合成包套件；要求退出 0 且 `FAIL=0` | `scripts/verify-package.ps1` |
| 原生扩展 | 注册 Role 和 Skill，声明可选 CLI/env/API 依赖 | [扩展指南](docs/zh-CN/extending.md) |
| 专业能力 | 新增 22 个方法，覆盖软件、本地资产、图像和音视频/文档，以及 4 个新角色 | [能力指南](docs/zh-CN/professional-capabilities.md) |
| Git 证据 | 6 个校验阶段：sourceRegistered、review、preMerge、postMerge、final、audit | `scripts/validate-git-evidence.ps1` |

## 快速开始

要求：Windows、PowerShell 7+、Git、Claude Code、Orca Runtime，以及本包（专业 Skill 已包含在 `skills/` 下）。原有十六个追溯到 [orca-professional-skills](https://github.com/guanwenpeng2001-bot/orca-professional-skills)；其后的 Skill 各自保留自己的上游和许可证，见 [docs/zh-CN/professional-capabilities.md](docs/zh-CN/professional-capabilities.md)。完整说明与排障见 [docs/zh-CN/installation.md](docs/zh-CN/installation.md)。

```powershell
# 1. 把包克隆到技能根目录
git clone https://github.com/guanwenpeng2001-bot/orca-project-delivery.git "$env:USERPROFILE\.agents\skills\orca-project-delivery"

# 2. 离线校验包（期望：SUMMARY PASS=<n> FAIL=0，退出码 0）
pwsh -NoProfile -File "$env:USERPROFILE\.agents\skills\orca-project-delivery\scripts\verify-package.ps1"
```

然后以协调者身份，从控制工作树打开本 Skill 并遵循 `SKILL.md`：引导项目、创建运行、派发工作者、审查、集成、关闭。完整走读在 [docs/zh-CN/usage.md](docs/zh-CN/usage.md)。

## 仓库结构

```text
orca-project-delivery/
├── SKILL.md                  # 协调者入口（17 节，不超过 250 行）
├── LICENSE                   # MIT
├── VERSION                   # 2.3.0
├── PACKAGE-MANIFEST.json     # 包元数据与交付物计数
├── CHANGELOG.md
├── README.md                 # 英文（默认）
├── README.zh-CN.md           # 简体中文
├── docs/
│   ├── installation.md       # 安装、校验、升级、卸载、排障（英文）
│   ├── usage.md              # 端到端协调者走读（英文）
│   ├── architecture.md       # 设计：平面、角色、工作流、证据、不变量（英文）
│   ├── extending.md          # 原生 Role/Skill 扩展与执行配置（英文）
│   ├── professional-skills.md
│   ├── professional-capabilities.md
│   ├── professional-capability-tutorial.md
│   ├── faq.md                # 常见问题与排障（英文）
│   └── zh-CN/                # 上述指南的简体中文译本
├── references/               # 11 篇深入参考（运行时、分支模型、证据等）
├── roles/                    # 16 份角色合同 + catalog.json
├── routing/                  # 模型、角色、Skill、工作流路由表
├── skills/                   # 38 个随包专业 Skill + LICENSE + README
├── workflows/                # 4 个工作流定义
├── schemas/                  # 状态、证据、依赖与配置的 JSON schema
├── scripts/                  # 交付与配置的 PowerShell 辅助脚本
└── templates/                # AGENTS.md、任务/审查/报告模板、.dev-work 种子
```

## 文档

| 文档 | 内容 |
| --- | --- |
| [安装](docs/zh-CN/installation.md) | 前置条件、目录约定、安装步骤、校验、升级、卸载、常见安装失败 |
| [专业 Skill](docs/zh-CN/professional-skills.md) | 全部 38 个工作者 Skill、逐个来源、安装布局与排障 |
| [专业能力](docs/zh-CN/professional-capabilities.md) | 新增的 22 个方法与 4 个角色：范围、证据标签、许可证 |
| [能力教程](docs/zh-CN/professional-capability-tutorial.md) | 离线安装检查与依赖辅助脚本走读；不调用提供方 |
| [扩展与配置](docs/zh-CN/extending.md) | 原生 Role/Skill 编写、依赖声明、字面配置及离线子进程执行走读 |
| [使用](docs/zh-CN/usage.md) | 从协调者入口开始一次交付、完整阶段顺序、角色/模型路由、分支与工作树规则、证据与报告、工作者回执、问答 |
| [架构](docs/zh-CN/architecture.md) | 控制平面与交付平面、权威来源、角色/工作流/Skill 表、证据模型、协调者锁、12 条不变量 |
| [常见问题](docs/zh-CN/faq.md) | 常见问题与失败模式排障 |
| [变更日志](CHANGELOG.md) | 发布历史（英文） |
| [English](README.md) | English README |

包内参考文档（`references/`）写给运行时的协调者，比公开文档更深；从 `SKILL.md` 开始，顺着它的链接读。

## 许可证

本项目的原创部分采用 MIT 许可证 — 见 [LICENSE](LICENSE)。简言之：你可以自由使用、复制、修改、合并、发布、分发、再许可和/或出售本软件的副本，但须在所有副本或软件的重要部分中包含版权声明和许可声明。本软件按「原样」提供，不作任何明示或暗示的保证。

第三方材料保留它被纳入时所依据的许可证。改编的 Skill 在 `skills/README.md` 中记录其上游、固定提交和许可证；一个 Apache-2.0 的 Skill 不会被重新许可为 MIT。见[专业能力](docs/zh-CN/professional-capabilities.md#许可证与来源)。
