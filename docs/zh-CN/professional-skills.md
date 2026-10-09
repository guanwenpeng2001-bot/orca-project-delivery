# 专业 Skill

[English](../professional-skills.md) | **简体中文**

Orca Project Delivery 协调的工作者会加载**专业 Skill** — 只提供方法的说明包（`SKILL.md`），覆盖侦察、产品工作、架构、实施、审查和验证。全部十六个 Skill **随本包**放在 `skills/<skill-id>/SKILL.md`。

## 上游来源

| 项 | 值 |
| --- | --- |
| 仓库 | [orca-professional-skills](https://github.com/guanwenpeng2001-bot/orca-professional-skills) |
| 来源提交（导入） | `d9a174c7143bfb4c76ed042f457fb7785c35cea3` |
| 随包布局 | 本仓库中的 `skills/<skill-id>/SKILL.md` |
| 许可证 | MIT — `skills/LICENSE`（亦见包根目录 `LICENSE`） |
| 完整性表 | `skills/README.md`（每个文件的 SHA256） |

记录的提交是上游基线。当前正文是包内维护的 MIT 改编版，已补充领域方法、判断标准、完整示例、失败信号与评估场景。可以有意识地就地编辑，并重新计算 `skills/README.md` 中当前内容的 SHA256 表；保留 `skills/LICENSE` 中未改动的上游 MIT 声明。哈希跟踪当前改编内容，不表示与上游逐字节一致。编写、注册与校验见[扩展指南](extending.md)。

## 十六个 Skill

`routing/skill-catalog.json` 中的路径相对于本包，解析为包根下的 `skills/<skill-id>/SKILL.md`。

| Skill ID | 用途 |
| --- | --- |
| `codebase-reconnaissance` | 针对有范围的事实问题检查代码、分支、历史、配置和测试，不修改源码。 |
| `technical-research` | 从一手来源、代码、标准和可复现实验研究技术行为。 |
| `product-discovery` | 把模糊的产品意图变成问题、用户、结果、范围、非目标和验收方向。 |
| `product-design` | 设计流程、信息架构、交互状态、可访问性和可测试的 UX 验收。 |
| `requirements-analysis` | 从目标与证据产出可追溯、可测试的功能与非功能需求。 |
| `solution-architecture` | 为有范围的变更设计边界、接口、数据流、迁移、回滚和运行行为。 |
| `api-design` | 设计 HTTP / RPC / 事件 / CLI / 模块合同，含校验、错误、幂等、认证和兼容性。 |
| `database-design` | 设计模型、约束、迁移、事务、索引、查询、保留和回滚。 |
| `implementation-planning` | 把已批准的设计拆成带范围、验收、测试、角色、Skill、分支和报告的任务。 |
| `test-driven-development` | 用 RED-GREEN-REFACTOR 和聚焦的自动化测试实现行为。 |
| `systematic-debugging` | 以证据驱动的假设复现、隔离、解释、修复并验证缺陷。 |
| `code-review` | 针对正确性、生命周期、并发、错误、可维护性和测试做独立审查。 |
| `security-review` | 审查信任边界、认证、输入、密钥、注入、依赖和滥用路径。 |
| `performance-review` | 测量并分析延迟、吞吐、查询、内存、并发和容量。 |
| `integration-verification` | 用命令、运行时证据、集成检查和明确跳过项验证验收。 |
| `merge-conflict-resolution` | 依据分支意图、基线、历史、接口和测试解决合并冲突。 |

## 安装

1. 克隆本协调者包（见 [installation.md](installation.md)）。
2. 运行 `scripts/verify-package.ps1` — Skill 路径检查期望每个随包的 `skills/<skill-id>/SKILL.md` 都存在于包内。不需要单独克隆或复制 Skill。

## 这些 Skill 不是什么

- 它们**不是**编排控制：不启动 Run、不派发工作者、不合并分支，也不扩大任务范围。
- 它们**不替代**全局 Orca Skill（`orchestration`、`orca-cli`、`orca-per-workspace-env`）。
- 它们**不**表示与 Anthropic、Orca 或上述链接的 MIT 许可仓库之外的任何厂商有从属关系。

## 缺了什么的时候

| 症状 | 可能原因 | 检查什么 |
| --- | --- | --- |
| `verify-package.ps1` 的 Skill 路径 FAIL | 随包文件缺失或损坏 | `Test-Path <package>/skills/<skill-id>/SKILL.md`；对照 `skills/README.md` 中的哈希 |
| 工作者读不到分配的 Skill | 任务中的路径错误，或沙箱限制 | 任务的 `explicit-path` 指向一个实际存在的随包 `SKILL.md` |
| 目录列出了 Skill 但文件不在 | 检出不完整或本地删除 | 从 Git 恢复；重跑完整性检查 |
| 手工编辑后哈希不匹配 | 当前正文与完整性表不一致 | 审阅有意改编，重新计算 SHA256 并更新表；意外修改从包 Git 恢复 |

协调者行为与证据路径见 [usage.md](usage.md) 和 `references/evidence-binding.md`。
