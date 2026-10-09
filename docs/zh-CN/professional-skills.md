# 专业 Skill

[English](../professional-skills.md) | **简体中文**

Orca Project Delivery 协调的工作者会加载**专业 Skill** — 提供专业方法的说明包（`SKILL.md`），覆盖侦察、产品工作、架构、实施、审查和验证，以及软件交付、本地资产、图像和音视频、文档的方法。计划中的 2.4.0 版本中，全部四十六个 Skill **随本包**放在 `skills/<skill-id>/SKILL.md`。部分方法还附带本地脚本或提供方连接器；执行证据与加载说明分开。安装完整且匹配的版本，并按[教程](professional-capability-tutorial.md)核对版本和目录。版本不匹配就不是本版本。

## 上游来源

出处在 `skills/README.md` 中**按 Skill** 记录：原有十六个的固定上游与 MIT 声明，以及后续原创方法的公开参考。

| 组 | 来源 | 许可证 |
| --- | --- | --- |
| 原有十六个 | [orca-professional-skills](https://github.com/guanwenpeng2001-bot/orca-professional-skills) 的 `d9a174c7143bfb4c76ed042f457fb7785c35cea3`，其后由本包维护 | MIT — `skills/LICENSE`，另加项目 MIT `LICENSE` |
| 2.3.0 新增的二十二个及 2.4.0 新增的八个 | 在本项目内编写，引用公开规范或文档，不复制上游 Skill 文本 | 项目 MIT；没有 Skill 附带 `LICENSE.txt` |

本项目的 MIT 许可证只覆盖它的原创部分。它不重新许可第三方材料。有两个上游有意缺席：Anthropic 的 docx、pptx、pdf 和 xlsx Skill 是专有的，不复制；OpenMontage（AGPL-3.0）不复制。规则和逐项能力的状态见[专业能力](professional-capabilities.md)。

记录的提交是原有十六个的上游基线。它们的当前正文是包内维护的 MIT 改编版，已补充领域方法、判断标准、完整示例、失败信号与评估场景。可以有意识地就地编辑任何 Skill，并重新计算 `skills/README.md` 中它的当前内容 SHA256 行；保留 `skills/LICENSE` 中未改动的上游 MIT 声明。哈希跟踪当前改编内容，不表示与上游逐字节一致。编写、注册与校验见[扩展指南](extending.md)。

## 原有的十六个 Skill

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

## 2.3.0 新增的二十二个

这些 Skill 的范围、证据标签和许可规则见[专业能力](professional-capabilities.md)。下面的一行用途是合同，不是测试结果。

| Skill | 用途 |
| --- | --- |
| `frontend-visual-design` | 排版、色彩和视觉层级，对照层级、错误态、键盘路径和缩放来检查。 |
| `browser-e2e` | 浏览器回归：选择器策略、trace 取证、夹具处理，附带由 Node 调用的本地 Python Playwright 示例。 |
| `accessibility-audit` | 可访问性证据：焦点顺序、标签、错误关联、对比度。自动扫描不是 WCAG 符合性。 |
| `postgres-practices` | PostgreSQL 索引、`EXPLAIN` 和行级安全，在独立测试数据库上测量。 |
| `observability` | 先确定要回答的运行问题，再布置指标、日志和追踪。供应商中立。 |
| `ci-pipeline` | 按项目真实拥有的检查来组织质量门。 |
| `react-performance` | React 和 Next.js 的请求瀑布与包体积规则，只用于 React 任务。 |
| `react-composition` | 组件组合、状态共享和布尔属性膨胀。仅 React 19 适用的建议只在被点名时生效。 |
| `icon-assets` | 图标选择，按图标集记录来源和许可。Iconify 查询需要网络，不需要密钥。 |
| `svg-logo-design` | SVG Logo 设计与导出检查，只用本地工具。 |
| `web-assets` | 从本地母版生成 favicon、manifest 和社交图片尺寸，使用 Node 生成 manifest 和有界 PNG 导出。 |
| `image-compression` | 本地图片压缩，给出实测压缩比并保留透明度。不保证任何压缩比。 |
| `image-generation` | 针对一个选定图像后端的提示词、宽高比和验收检查。生成是在线的且未验证。 |
| `infographic-design` | 信息图的版式、阅读顺序，以及它必须承载的结论。 |
| `editorial-illustration` | 封面和文章配图的方向。 |
| `visual-slide-deck` | 以图片呈现的幻灯片序列。图片型 deck 不是可编辑的 Office 文档。 |
| `code-video-production` | 以帧规划、在本地渲染的代码讲解视频。HyperFrames 是优先方法。 |
| `generated-video` | 向在线提供方请求的视频。真实在线，未验证；没有选定提供方。 |
| `speech-production` | 对一段指定文本做语音合成。真实在线，未验证。 |
| `audio-transcription` | 对一段给定录音做转录和时间戳。真实在线，未验证。 |
| `media-transcoding` | 用 FFmpeg 在本地剪切、重封装和转码，依据 FFmpeg 自身文档编写。 |
| `document-production` | 可编辑的文档、幻灯片、电子表格和 PDF，基于许可允许的库编写。 |

## 2.4.0 新增的八个

七个是方法（部分带离线示例检查），一个附带本地字幕转换器。其他 2.4.0 改动增强上述既有 Skill。范围与限制见[专业能力](professional-capabilities.md#工程方法)。

| Skill | 用途 |
| --- | --- |
| `skill-authoring-evaluation` | 评估触发、反例与可观察结果。 |
| `design-system` | 跨屏共享原始、语义与组件 token。 |
| `domain-modeling` | 实体、值对象、聚合及不变量归属。 |
| `migration-upgrade` | 扩展、双路径运行、切换、收缩与回滚边界。 |
| `mcp-server-development` | MCP 工具 schema、传输与协议/工具错误区分。 |
| `technical-diagrams` | 可读且有可访问描述的 SVG 与 Mermaid 源码。 |
| `localization` | 术语表、ICU 占位符、文本膨胀与从右到左布局。 |
| `subtitle-production` | SRT 与 WebVTT 纯文本字幕离线互转。 |

## 安装

1. 克隆本协调者包（见 [installation.md](installation.md)）。
2. 运行 `scripts/verify-package.ps1` — Skill 路径检查期望每个随包的 `skills/<skill-id>/SKILL.md` 都存在于包内。不需要单独克隆或复制 Skill。

## 这些 Skill 不是什么

- 它们**不是**编排控制：不启动 Run、不派发工作者、不合并分支，也不扩大任务范围。
- 它们**不替代**全局 Orca Skill（`orchestration`、`orca-cli`、`orca-per-workspace-env`）。
- 它们**不**表示与 Anthropic、Orca 或任何被当作示例连接器提及的厂商有从属关系，提及一个厂商也不构成选择。

## 缺了什么的时候

| 症状 | 可能原因 | 检查什么 |
| --- | --- | --- |
| `verify-package.ps1` 的 Skill 路径 FAIL | 随包文件缺失或损坏 | `Test-Path <package>/skills/<skill-id>/SKILL.md`；对照 `skills/README.md` 中的哈希 |
| 工作者读不到分配的 Skill | 任务中的路径错误，或沙箱限制 | 任务的 `explicit-path` 指向一个实际存在的随包 `SKILL.md` |
| 目录列出了 Skill 但文件不在 | 检出不完整或本地删除 | 从 Git 恢复；重跑完整性检查 |
| 手工编辑后哈希不匹配 | 当前正文与完整性表不一致 | 审阅有意改编，重新计算 SHA256 并更新表；意外修改从包 Git 恢复 |

协调者行为与证据路径见 [usage.md](usage.md) 和 `references/evidence-binding.md`。
